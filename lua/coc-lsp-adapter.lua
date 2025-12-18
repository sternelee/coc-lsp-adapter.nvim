local M = {}

local native = {
    get_active_clients = vim.lsp.get_active_clients,
    get_clients = vim.lsp.get_clients,
    get_client_by_id = vim.lsp.get_client_by_id,
    buf_get_clients = vim.lsp.buf_get_clients,
}

local server_capabilities = {
    java = {
        executeCommandProvider = {
            commands = {
                'java.project.getClasspaths',
                'vscode.java.checkProjectSettings',
                'vscode.java.resolveClasspath',
                'vscode.java.resolveJavaExecutable',
                'vscode.java.resolveMainClass',
                'vscode.java.startDebugSession',
                'vscode.java.test.findTestTypesAndMethods',
                'vscode.java.test.junit.argument',
            }
        }
    }
}

local coc_services
local async_counter = 0
local function get_coc_clients(filter)
    filter = filter or {}
    local coc_clients = {}
    if async_counter < 0 then
        async_counter = 0
    end
    if async_counter == 0 then
        coc_services = vim.fn['CocAction']('services')
    end
    for id, service in pairs(coc_services) do
        if service.state ~= 'running' then
            goto skip_coc_service
        end

        local client = {
            id = id,
            name = service.id,
            language_ids = service.languageIds,
            server_capabilities = server_capabilities[service.id] or {},
        }

        ---@diagnostic disable-next-line: unused-local
        function client.request(method, params, callback, bufnr)
            local callback_wrapper = function(err, result)
                if err == vim.NIL then
                    err = nil
                end
                async_counter = async_counter - 1
                callback(err, result)
            end
            async_counter = async_counter + 1
            vim.fn['CocRequestAsync'](client.name, method, params, callback_wrapper)
            return true
        end

        ---@diagnostic disable-next-line: unused-local
        function client.request_sync(method, params, timeout_ms, bufnr)
            return vim.fn['CocRequest'](client.name, method, params)
        end

        function client.notify(method, params)
            vim.fn['CocNotify'](client.name, method, params)
            return true
        end

        table.insert(coc_clients, client)

        ::skip_coc_service::
    end
    if type(filter.id) == 'number' or type(filter.id) == 'string' then
        for _, client in pairs(coc_clients) do
            if client.id == filter.id then
                return { client }
            end
        end
        return {}
    end
    if type(filter.name) == 'string' then
        for _, client in pairs(coc_clients) do
            if client.name == filter.name then
                return { client }
            end
        end
        return {}
    end
    return coc_clients
end

local function get_active_clients(filter)
    filter = filter or {}
    local native_clients = {}
    if native.get_active_clients then
        native_clients = native.get_active_clients(filter)
    elseif native.get_clients then
        native_clients = native.get_clients(filter)
    end
    if vim.tbl_count(native_clients) > 0 or vim.g.coc_enabled ~= 1 then
        return native_clients
    end
    return get_coc_clients(filter)
end

local function get_clients(filter)
    filter = filter or {}
    if native.get_clients then
        local native_clients = native.get_clients(filter)
        if vim.tbl_count(native_clients) > 0 or vim.g.coc_enabled ~= 1 then
            return native_clients
        end
    end
    return get_coc_clients(filter)
end

local function get_client_by_id(id)
    if native.get_client_by_id then
        local client = native.get_client_by_id(id)
        if client ~= nil or vim.g.coc_enabled ~= 1 then
            return client
        end
    end
    local clients = get_coc_clients({ id = id })
    return clients[1]
end

local function buf_get_clients(bufnr)
    return get_clients({
        bufnr = bufnr,
        buffer = bufnr,
    })
end

M.native = native
M.server_capabilities = server_capabilities
M.lsp = {
    get_active_clients = get_active_clients,
    get_clients = get_clients,
    get_client_by_id = get_client_by_id,
    buf_get_clients = buf_get_clients,
}

function M.setup()
    vim.lsp.get_active_clients = get_active_clients
    vim.lsp.get_clients = get_clients
    vim.lsp.get_client_by_id = get_client_by_id
    vim.lsp.buf_get_clients = buf_get_clients
end

return M
