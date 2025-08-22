-- ROM Mount/Unmount Tool para CC Tweaked
-- Uso: lua rom_tool.lua mount archivo.rom
--      lua rom_tool.lua unmount nombre

local args = {...}

if #args < 2 then
    print("Uso:")
    print("  mount <archivo.rom>   - Monta un archivo ROM")
    print("  unmount <nombre>      - Desmonta un ROM")
    return
end

local command = args[1]:lower()
local target = args[2]

-- Función para crear directorio si no existe
local function ensureDir(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

-- Función para leer archivo ROM (binario)
local function readROM(romFile)
    if not fs.exists(romFile) then
        error("El archivo ROM no existe: " .. romFile)
    end
    
    local file = fs.open(romFile, "rb")
    if not file then
        error("No se pudo abrir el archivo ROM: " .. romFile)
    end
    
    local data = file.readAll()
    file.close()
    
    return data
end

-- Función para extraer datos del ROM (formato simple)
local function extractROMData(romData)
    -- Aquí puedes implementar tu formato de ROM personalizado
    -- Por ahora, trataremos el ROM como datos sin procesar
    local files = {}
    
    -- Formato simple: cada archivo separado por un delimitador especial
    -- Por ejemplo: "FILENAME\0CONTENT\0FILENAME2\0CONTENT2\0"
    local pos = 1
    while pos <= #romData do
        -- Buscar nombre de archivo (hasta \0)
        local nameEnd = romData:find("\0", pos)
        if not nameEnd then break end
        
        local filename = romData:sub(pos, nameEnd - 1)
        pos = nameEnd + 1
        
        -- Buscar contenido (hasta siguiente \0)
        local contentEnd = romData:find("\0", pos)
        if not contentEnd then
            -- Último archivo, tomar todo el resto
            contentEnd = #romData + 1
        end
        
        local content = romData:sub(pos, contentEnd - 1)
        files[filename] = content
        pos = contentEnd + 1
    end
    
    return files
end

-- Función MOUNT
local function mountROM(romFile)
    print("Mounting rom \"" .. romFile .. "\"..")
    
    -- Leer el archivo ROM
    local romData = readROM(romFile)
    
    -- Extraer nombre sin extensión
    local romName = romFile:match("([^/\\]+)%.rom$") or romFile
    
    -- Crear directorio /dev si no existe
    ensureDir("/dev")
    
    -- Crear directorio para este ROM
    local mountPoint = "/dev/" .. romName
    ensureDir(mountPoint)
    
    -- Extraer archivos del ROM
    local files = extractROMData(romData)
    
    -- Si no hay archivos estructurados, guardar el ROM como archivo único
    if next(files) == nil then
        local file = fs.open(mountPoint .. "/data", "wb")
        file.write(romData)
        file.close()
    else
        -- Guardar cada archivo extraído
        for filename, content in pairs(files) do
            local file = fs.open(mountPoint .. "/" .. filename, "w")
            file.write(content)
            file.close()
        end
    end
    
    print("Done! Thank Jehovah!")
end

-- Función UNMOUNT
local function unmountROM(romName)
    print("Unmount rom: " .. romName .. "..")
    
    local romFile = romName .. ".rom"
    local mountPoint = "/dev/" .. romName
    
    -- Verificar que el ROM existe
    if not fs.exists(romFile) then
        print("Error: ROM file not found: " .. romFile)
        return
    end
    
    -- Verificar que el punto de montaje existe
    if not fs.exists(mountPoint) then
        print("Error: Mount point not found: " .. mountPoint)
        return
    end
    
    -- Borrar el directorio montado
    fs.delete(mountPoint)
    
    -- Si /dev está vacío, también lo borramos
    local devContents = fs.list("/dev")
    if #devContents == 0 then
        fs.delete("/dev")
    end
    
    print("Done! Thank Jehovah!")
end

-- Ejecutar comando
if command == "mount" then
    if not target:match("%.rom$") then
        print("Error: El archivo debe tener extensión .rom")
        return
    end
    mountROM(target)
elseif command == "unmount" then
    unmountROM(target)
else
    print("Comando desconocido: " .. command)
    print("Usa 'mount' o 'unmount'")
end
