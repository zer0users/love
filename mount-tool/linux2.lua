-- Terminal Linux Real - Cliente CC Tweaked para conectar a Linux real
-- Soporte completo para colores, clear, pipes, redirección, etc.

local LinuxTerminal = {
    server_url = nil,
    session_id = nil,
    username = nil,
    hostname = nil,
    current_dir = "/",
    shell_pid = nil,
    connected = false,
    colors_enabled = true
}

-- Mapeo de colores ANSI a CC
local ansi_colors = {
    ["0"] = colors.black,      -- Negro
    ["1"] = colors.red,        -- Rojo
    ["2"] = colors.green,      -- Verde  
    ["3"] = colors.yellow,     -- Amarillo
    ["4"] = colors.blue,       -- Azul
    ["5"] = colors.purple,     -- Magenta
    ["6"] = colors.cyan,       -- Cian
    ["7"] = colors.white,      -- Blanco
    ["8"] = colors.gray,       -- Negro brillante
    ["9"] = colors.red,        -- Rojo brillante
    ["10"] = colors.lime,      -- Verde brillante
    ["11"] = colors.yellow,    -- Amarillo brillante
    ["12"] = colors.lightBlue, -- Azul brillante
    ["13"] = colors.magenta,   -- Magenta brillante
    ["14"] = colors.cyan,      -- Cian brillante
    ["15"] = colors.white      -- Blanco brillante
}

-- Parsear secuencias de escape ANSI para colores
local function parseAnsiColors(text)
    -- Remover secuencias ANSI y aplicar colores a CC
    local result = {}
    local current_color = colors.white
    local i = 1
    
    while i <= #text do
        local esc_start = text:find("\27%[", i)
        
        if not esc_start then
            -- No más secuencias, agregar resto del texto
            table.insert(result, {text:sub(i), current_color})
            break
        end
        
        -- Agregar texto antes de la secuencia
        if esc_start > i then
            table.insert(result, {text:sub(i, esc_start - 1), current_color})
        end
        
        -- Buscar el final de la secuencia
        local esc_end = text:find("m", esc_start)
        if esc_end then
            local sequence = text:sub(esc_start + 2, esc_end - 1)
            
            -- Parsear códigos de color
            for code in sequence:gmatch("(%d+)") do
                if code == "0" then
                    current_color = colors.white -- Reset
                elseif code == "1" then
                    -- Bold (no se puede en CC, ignorar)
                elseif code:match("^3[0-7]$") then
                    -- Color de foreground
                    local color_num = code:sub(2)
                    current_color = ansi_colors[color_num] or colors.white
                elseif code:match("^9[0-7]$") then
                    -- Color brillante de foreground  
                    local color_num = tostring(tonumber(code:sub(2)) + 8)
                    current_color = ansi_colors[color_num] or colors.white
                end
            end
            
            i = esc_end + 1
        else
            -- Secuencia malformada, saltar
            i = esc_start + 2
        end
    end
    
    return result
end

-- Mostrar texto con colores
local function displayColoredText(colored_segments)
    for _, segment in ipairs(colored_segments) do
        local text, color = segment[1], segment[2]
        term.setTextColor(color)
        write(text)
    end
    term.setTextColor(colors.white)
end

-- Conectar al servidor Linux
local function connectToLinux()
    term.clear()
    term.setCursorPos(1, 1)
    
    print("=== Linux Terminal Client ===")
    print("")
    
    write("Linux Server IP/Host: ")
    local host = read()
    if host == "" then host = "localhost" end
    
    write("Port (default 5000): ")
    local port = read()
    if port == "" then port = "5000" end
    
    LinuxTerminal.server_url = "http://" .. host .. ":" .. port
    
    print("")
    print("Connecting to " .. LinuxTerminal.server_url .. "...")
    
    -- Iniciar sesión de terminal
    local init_response = http.request({
        url = LinuxTerminal.server_url .. "/terminal/init",
        method = "POST",
        headers = {["Content-Type"] = "application/json"},
        body = textutils.serialiseJSON({
            term_type = "xterm-256color",
            width = 51,  -- Ancho de CC
            height = 19  -- Alto de CC
        })
    })
    
    if not init_response then
        print("Failed to connect to server!")
        print("Make sure your Flask server is running.")
        return false
    end
    
    local response_data = init_response.readAll()
    init_response.close()
    
    local success, data = pcall(textutils.unserialiseJSON, response_data)
    if success and data.session_id then
        LinuxTerminal.session_id = data.session_id
        LinuxTerminal.shell_pid = data.shell_pid
        LinuxTerminal.connected = true
        
        print("Connected! Session ID: " .. LinuxTerminal.session_id)
        sleep(1)
        return true
    else
        print("Server error: " .. (data and data.error or "Unknown error"))
        return false
    end
end

-- Enviar comando al Linux
local function sendCommand(command)
    if not LinuxTerminal.connected then return nil end
    
    local response = http.request({
        url = LinuxTerminal.server_url .. "/terminal/execute",
        method = "POST",
        headers = {["Content-Type"] = "application/json"},
        body = textutils.serialiseJSON({
            session_id = LinuxTerminal.session_id,
            command = command
        })
    })
    
    if not response then
        return {error = "Connection lost"}
    end
    
    local response_data = response.readAll()
    response.close()
    
    local success, data = pcall(textutils.unserialiseJSON, response_data)
    if success then
        return data
    else
        return {error = "Invalid response"}
    end
end

-- Obtener información del sistema
local function getSystemInfo()
    local info = sendCommand("uname -a && whoami && hostname && pwd")
    if info and info.output then
        local lines = {}
        for line in info.output:gmatch("([^\n]*)\n?") do
            if line ~= "" then table.insert(lines, line) end
        end
        
        if #lines >= 4 then
            LinuxTerminal.username = lines[2]
            LinuxTerminal.hostname = lines[3] 
            LinuxTerminal.current_dir = lines[4]
        end
    end
end

-- Shell principal con colores y comandos reales
local function runShell()
    term.clear()
    term.setCursorPos(1, 1)
    
    -- Obtener info del sistema
    getSystemInfo()
    
    -- Mostrar banner
    print("Connected to real Linux system!")
    local sysinfo = sendCommand("uname -sr && uptime")
    if sysinfo and sysinfo.output then
        local colored = parseAnsiColors(sysinfo.output)
        displayColoredText(colored)
    end
    print("")
    
    while LinuxTerminal.connected do
        -- Actualizar directorio actual
        local pwd_result = sendCommand("pwd")
        if pwd_result and pwd_result.output then
            LinuxTerminal.current_dir = pwd_result.output:gsub("\n", "")
        end
        
        -- Prompt colorizado como Linux real
        term.setTextColor(colors.green)
        write(LinuxTerminal.username or "user")
        term.setTextColor(colors.white)
        write("@")
        term.setTextColor(colors.green) 
        write(LinuxTerminal.hostname or "linux")
        term.setTextColor(colors.white)
        write(":")
        term.setTextColor(colors.blue)
        write(LinuxTerminal.current_dir or "/")
        term.setTextColor(colors.white)
        write("$ ")
        
        local command = read()
        
        -- Comandos especiales del cliente
        if command == "exit" or command == "logout" then
            break
        elseif command == "cc-clear" then
            term.clear()
            term.setCursorPos(1, 1)
        elseif command == "cc-colors" then
            LinuxTerminal.colors_enabled = not LinuxTerminal.colors_enabled
            print("Colors " .. (LinuxTerminal.colors_enabled and "enabled" or "disabled"))
        elseif command:sub(1, 9) == "cc-upload" then
            local filename = command:sub(11)
            uploadFile(filename)
        elseif command:sub(1, 11) == "cc-download" then
            local filename = command:sub(13)
            downloadFile(filename)
        else
            -- Enviar comando real a Linux
            local result = sendCommand(command)
            
            if result then
                if result.error then
                    term.setTextColor(colors.red)
                    print("Error: " .. result.error)
                    term.setTextColor(colors.white)
                else
                    -- Mostrar salida con colores
                    if result.output and result.output ~= "" then
                        if LinuxTerminal.colors_enabled then
                            local colored = parseAnsiColors(result.output)
                            displayColoredText(colored)
                        else
                            write(result.output:gsub("\27%[[0-9;]*m", "")) -- Remover ANSI
                        end
                    end
                    
                    -- Mostrar errores
                    if result.stderr and result.stderr ~= "" then
                        term.setTextColor(colors.red)
                        write(result.stderr)
                        term.setTextColor(colors.white)
                    end
                end
            end
        end
    end
    
    -- Cerrar sesión
    if LinuxTerminal.session_id then
        http.request({
            url = LinuxTerminal.server_url .. "/terminal/close",
            method = "POST", 
            headers = {["Content-Type"] = "application/json"},
            body = textutils.serialiseJSON({
                session_id = LinuxTerminal.session_id
            })
        })
    end
    
    print("")
    print("Connection closed. Goodbye!")
end

-- Subir archivo a Linux
local function uploadFile(filename)
    if not fs.exists(filename) then
        print("Local file not found: " .. filename)
        return
    end
    
    local file = fs.open(filename, "r")
    local content = file.readAll()
    file.close()
    
    print("Uploading " .. filename .. " to Linux...")
    
    local response = http.request({
        url = LinuxTerminal.server_url .. "/file/upload",
        method = "POST",
        headers = {["Content-Type"] = "application/json"},
        body = textutils.serialiseJSON({
            session_id = LinuxTerminal.session_id,
            filename = filename,
            content = content
        })
    })
    
    if response then
        local data = response.readAll()
        response.close()
        print("Upload result: " .. data)
    else
        print("Upload failed!")
    end
end

-- Descargar archivo de Linux  
local function downloadFile(filename)
    print("Downloading " .. filename .. " from Linux...")
    
    local response = http.request({
        url = LinuxTerminal.server_url .. "/file/download",
        method = "POST",
        headers = {["Content-Type"] = "application/json"},
        body = textutils.serialiseJSON({
            session_id = LinuxTerminal.session_id,
            filename = filename
        })
    })
    
    if response then
        local result = response.readAll()
        response.close()
        
        local success, data = pcall(textutils.unserialiseJSON, result)
        if success and data.content then
            local file = fs.open(filename, "w")
            file.write(data.content)
            file.close()
            print("Downloaded: " .. filename)
        else
            print("Download failed: " .. (data and data.error or "Unknown error"))
        end
    else
        print("Connection failed!")
    end
end

-- Mostrar ayuda
local function showHelp()
    print("Linux Terminal Client - Special Commands:")
    print("  cc-clear      - Clear ComputerCraft screen")
    print("  cc-colors     - Toggle ANSI color support")  
    print("  cc-upload <file>   - Upload file to Linux")
    print("  cc-download <file> - Download file from Linux")
    print("  exit/logout   - Close connection")
    print("")
    print("All other commands are sent directly to Linux!")
end

-- Función principal
local function main()
    -- Obtener argumentos de línea de comandos si los hay
    local args = arg or {}
    
    if args[1] == "help" or args[1] == "--help" then
        showHelp()
        return
    end
    
    if connectToLinux() then
        runShell()
    else
        print("")
        print("Connection failed. Check that your Flask server is running.")
        print("Run with 'help' argument for more information.")
    end
end

-- Iniciar el terminal
main()
