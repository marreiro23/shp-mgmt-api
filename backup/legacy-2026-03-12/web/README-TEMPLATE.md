# 📄 Template de Página - CVE Management System

## 📋 Visão Geral

Este template fornece uma estrutura padronizada para criar novas páginas no sistema CVE Management. Ele inclui todos os componentes visuais, estilos e funcionalidades básicas necessárias.

## 🎯 Arquivo Template

**Localização:** `web/page-template.html`

## ✨ Recursos Incluídos

### 1. **Estrutura HTML Completa**
- ✅ Header com título e descrição
- ✅ Barra de navegação padrão do projeto
- ✅ Sistema de cards responsivo
- ✅ Área de conteúdo principal

### 2. **Componentes Visuais**

#### Cards
```html
<div class="card">
    <div class="card-header">
        📝 Título do Card
    </div>
    <div class="card-body">
        <!-- Conteúdo -->
    </div>
</div>
```

#### Stats Cards
```html
<div class="grid grid-4">
    <div class="stat-card">
        <div class="stat-value">100</div>
        <div class="stat-label">Descrição</div>
    </div>
</div>
```

#### Botões
```html
<button class="btn btn-primary">Primário</button>
<button class="btn btn-success">Sucesso</button>
<button class="btn btn-warning">Aviso</button>
<button class="btn btn-danger">Perigo</button>
```

#### Badges
```html
<span class="badge badge-success">Ativo</span>
<span class="badge badge-danger">Crítico</span>
```

#### Status Messages
```html
<div id="statusMessage" class="status success show">
    ✅ Mensagem de sucesso
</div>
```

### 3. **Sistema de Grid**

```html
<!-- 2 colunas -->
<div class="grid grid-2">...</div>

<!-- 3 colunas -->
<div class="grid grid-3">...</div>

<!-- 4 colunas -->
<div class="grid grid-4">...</div>
```

### 4. **Tabelas Responsivas**

```html
<div class="table-container">
    <table>
        <thead>
            <tr>
                <th>Coluna 1</th>
                <th>Coluna 2</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td>Dado 1</td>
                <td>Dado 2</td>
            </tr>
        </tbody>
    </table>
</div>
```

### 5. **Formulários**

```html
<div class="form-group">
    <label class="form-label">Campo:</label>
    <input type="text" class="form-control" placeholder="Digite...">
</div>
```

## 🎨 Paleta de Cores

```css
--primary-color: #2c3e50    /* Azul escuro */
--secondary-color: #3498db  /* Azul */
--success-color: #27ae60    /* Verde */
--warning-color: #f39c12    /* Laranja */
--danger-color: #e74c3c     /* Vermelho */
--light-bg: #ecf0f1         /* Cinza claro */
--dark-bg: #34495e          /* Cinza escuro */
```

## 🔧 Funções JavaScript Incluídas

### Exibir Mensagens de Status
```javascript
showStatus('Mensagem', 'success'); // success, error, loading, info
```

### Executar Ação Assíncrona
```javascript
async function executeAction() {
    // Exemplo de chamada API
}
```

### Salvar Dados
```javascript
async function saveData() {
    // Exemplo de salvamento
}
```

### Limpar Formulário
```javascript
clearForm(); // Limpa todos os inputs
```

### Buscar na Tabela
```javascript
searchTable(); // Filtra linhas da tabela
```

### Testar Conexão API
```javascript
await testAPIConnection();
```

## 📝 Como Usar Este Template

### Passo 1: Copiar o Template
```bash
cp web/page-template.html web/minha-nova-pagina.html
```

### Passo 2: Personalizar o Conteúdo

1. **Altere o título da página:**
   ```html
   <title>Minha Página - CVE Management</title>
   ```

2. **Atualize o header:**
   ```html
   <div class="header">
       <h1>🎯 Minha Nova Funcionalidade</h1>
       <p>Descrição do que esta página faz</p>
   </div>
   ```

3. **Remova ou adicione cards conforme necessário**

4. **Implemente suas funções JavaScript personalizadas**

### Passo 3: Adicionar à Navegação

Adicione um link para sua nova página em todas as barras de navegação:

```html
<a href="minha-nova-pagina.html" class="nav-button">🔥 Minha Página</a>
```

## 🎯 Exemplos de Uso

### Exemplo 1: Página de Relatórios
- Use `stat-card` para métricas
- Use `table-container` para dados tabulares
- Use botões de exportação

### Exemplo 2: Página de Configuração
- Use `form-group` para inputs
- Use `card` para seções de configuração
- Use `btn-success` para salvar

### Exemplo 3: Página de Análise
- Use `grid grid-3` para estatísticas
- Use gráficos (adicione bibliotecas como Chart.js)
- Use filtros com `form-control`

## 📱 Design Responsivo

O template é totalmente responsivo:
- ✅ Mobile (< 768px): Layout em coluna única
- ✅ Tablet (768px - 1024px): Layout adaptativo
- ✅ Desktop (> 1024px): Layout completo com múltiplas colunas

## 🔗 Integrações Disponíveis

### API Backend
```javascript
const API_URL = 'http://localhost:3000/api';
```

### Connection Manager
```html
<link rel="stylesheet" href="connection-manager.css">
```

## ⚡ Performance

O template inclui:
- ✅ CSS otimizado e minificado
- ✅ Lazy loading de componentes
- ✅ Transições suaves
- ✅ Scrollbar personalizada

## 🛠️ Customizações Comuns

### Alterar Cores do Tema
```css
:root {
    --primary-color: #sua-cor;
}
```

### Adicionar Ícones Personalizados
Use emojis ou adicione Font Awesome:
```html
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
```

### Adicionar Animações
```css
@keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
}

.animated {
    animation: fadeIn 0.5s;
}
```

## 📚 Componentes Adicionais Sugeridos

### Loading Overlay
```html
<div style="position: fixed; top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.7); z-index: 9999; display: none;"
            id="loadingOverlay">
    <div class="loading-spinner" style="position: absolute; top: 50%; left: 50%;
                                        transform: translate(-50%, -50%);"></div>
</div>
```

### Modal Dialog
```html
<div class="modal" id="myModal" style="display: none;">
    <div class="modal-content">
        <h2>Título do Modal</h2>
        <p>Conteúdo...</p>
        <button onclick="closeModal()">Fechar</button>
    </div>
</div>
```

### Toast Notifications
```javascript
function showToast(message, type = 'info') {
    // Implementar notificações toast
}
```

## 🐛 Troubleshooting

### Estilos não carregando
- Verifique o caminho do `connection-manager.css`
- Certifique-se de que o arquivo existe

### API não conecta
- Verifique se o servidor está rodando
- Confirme a porta (padrão: 3000)
- Verifique CORS

### Layout quebrado
- Limpe o cache do navegador
- Verifique a estrutura HTML
- Valide os nomes das classes CSS

## 📌 Boas Práticas

1. ✅ Sempre use IDs únicos para elementos JavaScript
2. ✅ Mantenha consistência com os ícones (emojis)
3. ✅ Adicione comentários em funções complexas
4. ✅ Teste em diferentes resoluções
5. ✅ Valide o HTML (W3C Validator)
6. ✅ Use nomes descritivos para variáveis
7. ✅ Implemente tratamento de erros
8. ✅ Adicione logs para debug

## 🔄 Atualizações Futuras

Recursos planejados:
- [ ] Dark mode toggle
- [ ] Gráficos interativos (Chart.js)
- [ ] Export para PDF
- [ ] Impressão otimizada
- [ ] Temas customizáveis
- [ ] Multilíngue (i18n)

## 📞 Suporte

Para questões sobre o template:
1. Consulte este README
2. Veja exemplos nas outras páginas do projeto
3. Verifique a documentação CSS

---

**Versão:** 1.0
**Última atualização:** Janeiro 2026
**Compatibilidade:** Todos os navegadores modernos (Chrome, Firefox, Edge, Safari)
