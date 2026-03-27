# Expandir recursos da API nas paginas HTML

## Objetivo

Adicionar um novo recurso da API em uma pagina HTML do frontend estatico (principalmente web/collaboration.html), com botao ativo e feedback de resposta.

## Quando usar este guia

- Quando um endpoint novo foi criado no backend e precisa aparecer na UI
- Quando um endpoint existente precisa de novos campos de entrada
- Quando um novo tipo de exportacao precisa ser suportado no seletor

## Passo a passo

## 1. Confirmar contrato da rota

Antes de alterar HTML, confirme no backend:

- rota em api/routes/sharepoint.routes.js
- validacao e formato de resposta em api/controllers/sharepointController.js

Checklist:

- metodo HTTP
- path com parametros
- body esperado
- codigos de sucesso e erro

## 2. Adicionar campos visuais

No bloco de painel adequado em web/collaboration.html:

1. adicione input/select com id unico
2. adicione botao com id unico
3. mantenha o padrao visual existente (.grid, .button-row)

Exemplo:

```html
<input id="userId" placeholder="user-id">
<button id="btnListUserLicenses" type="button">Listar licencas</button>
```

## 3. Criar funcao JavaScript

No script da pagina:

1. leia campos com byId(...).value.trim()
2. monte URL com encodeURIComponent
3. use fetchJson para manter envelope padrao
4. publique resultado com setOutput

Exemplo:

```javascript
async function listUserLicenses() {
  const userId = byId('userId').value.trim();
  const data = await fetchJson(`${API}/users/${encodeURIComponent(userId)}/licenses`);
  setOutput('Listar licencas', data);
}
```

## 4. Registrar evento do botao

Ainda em collaboration.html:

```javascript
byId('btnListUserLicenses').addEventListener('click', () =>
  listUserLicenses().catch((error) => setOutput('Erro', { message: error.message }))
);
```

## 5. Atualizar exportacao (quando aplicavel)

Se o recurso tambem precisa exportar:

1. adicione option no select exportSource
2. adicione campos necessarios para querystring
3. ajuste buildExportUrl para incluir os novos parametros
4. backend: incluir source no exportResults

## 6. Atualizar smoke tests web

Em api/test/web.pages.test.js:

- adicione asserts para os novos ids de botoes
- mantenha teste simples de presenca de controles ativos

Exemplo:

```javascript
expect(text).to.contain('id="btnListUserLicenses"');
```

## 7. Validar

Na pasta api/:

```bash
npm test
```

Valide tambem manualmente em:

- /web/collaboration.html

## Padrao recomendado para novos recursos

Para manter consistencia, sempre implementar este pacote minimo:

1. rota
2. controller
3. service
4. input/output no frontend
5. teste de rota
6. smoke test web
7. atualizacao de README/documentacao

## Erros comuns

- esquecer encodeURIComponent em ids de rota
- nao incluir handler de erro no addEventListener
- adicionar botao no HTML e esquecer de registrar evento
- criar source no frontend sem suporte no controller exportResults
