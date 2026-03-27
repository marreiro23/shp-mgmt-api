from typing import Any
from urllib.parse import quote

import httpx

from app.auth.token_provider import TokenProvider
from app.config import settings


class SharePointService:
    """Service layer responsible for direct Microsoft Graph REST calls."""

    def __init__(self, token_provider: TokenProvider) -> None:
        """Initialize service with authentication provider and HTTP settings."""
        self._token_provider = token_provider
        self._base_url = "https://graph.microsoft.com/v1.0"

    async def list_items(self, folder_path: str) -> dict[str, Any]:
        """List files and folders under a SharePoint drive folder path."""
        encoded_path = quote(folder_path.strip("/"))
        endpoint = (
            f"/sites/{settings.site_id}/drives/{settings.drive_id}/root:/"
            f"{encoded_path}:/children"
        )
        return await self._request("GET", endpoint)

    async def list_sites(
        self,
        search: str | None = None,
        top: int = 100,
    ) -> dict[str, Any]:
        """List SharePoint sites in the current tenant."""
        params: list[str] = []
        safe_top = max(1, min(top, 999))
        params.append(f"$top={safe_top}")
        if search:
            encoded_search = quote(search.strip())
            params.append(f"search={encoded_search}")

        query = "&".join(params)
        endpoint = f"/sites?{query}"
        return await self._request("GET", endpoint)

    async def create_folder(self, parent_path: str, folder_name: str) -> dict[str, Any]:
        """Create a folder under the provided SharePoint parent path."""
        encoded_parent_path = quote(parent_path.strip("/"))
        endpoint = (
            f"/sites/{settings.site_id}/drives/{settings.drive_id}/root:/"
            f"{encoded_parent_path}:/children"
        )
        payload = {
            "name": folder_name,
            "folder": {},
            "@microsoft.graph.conflictBehavior": "rename",
        }
        return await self._request("POST", endpoint, json=payload)

    async def upload_small_file(
        self,
        folder_path: str,
        file_name: str,
        file_content: bytes,
    ) -> dict[str, Any]:
        """Upload a small file to SharePoint using Graph simple upload."""
        encoded_full_path = quote(f"{folder_path.strip('/')}/{file_name}")
        endpoint = (
            f"/sites/{settings.site_id}/drives/{settings.drive_id}/root:/"
            f"{encoded_full_path}:/content"
        )
        return await self._request(
            "PUT",
            endpoint,
            content=file_content,
            headers={"Content-Type": "application/octet-stream"},
        )

    async def download_file(self, file_path: str) -> bytes:
        """Download file content from SharePoint."""
        encoded_path = quote(file_path.strip("/"))
        endpoint = (
            f"/sites/{settings.site_id}/drives/{settings.drive_id}/root:/"
            f"{encoded_path}:/content"
        )
        response = await self._request_raw("GET", endpoint)
        return response.content

    async def delete_item(self, item_path: str) -> dict[str, Any]:
        """Delete a file or folder by path from SharePoint."""
        encoded_path = quote(item_path.strip("/"))
        endpoint = (
            f"/sites/{settings.site_id}/drives/{settings.drive_id}/root:/"
            f"{encoded_path}"
        )
        await self._request("DELETE", endpoint)
        return {"deleted": True, "path": item_path}

    async def _request(
        self,
        method: str,
        endpoint: str,
        json: dict[str, Any] | None = None,
        content: bytes | None = None,
        headers: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        """Execute an authenticated Graph request and return JSON payload."""
        response = await self._request_raw(
            method=method,
            endpoint=endpoint,
            json=json,
            content=content,
            headers=headers,
        )
        if response.status_code == 204:
            return {"status": "no_content"}
        if not response.content:
            return {"status": "ok"}
        return response.json()

    async def _request_raw(
        self,
        method: str,
        endpoint: str,
        json: dict[str, Any] | None = None,
        content: bytes | None = None,
        headers: dict[str, str] | None = None,
    ) -> httpx.Response:
        """Execute an authenticated Graph request and return raw HTTP response."""
        access_token = self._token_provider.get_access_token()
        request_headers = {
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
        }
        if headers:
            request_headers.update(headers)

        async with httpx.AsyncClient(timeout=settings.request_timeout_seconds) as client:
            response = await client.request(
                method=method,
                url=f"{self._base_url}{endpoint}",
                json=json,
                content=content,
                headers=request_headers,
            )

        if response.status_code >= 400:
            raise RuntimeError(
                f"Graph request failed ({response.status_code}): {response.text}"
            )
        return response
