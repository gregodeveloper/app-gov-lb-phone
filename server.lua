local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")

local src = {}
Tunnel.bindInterface("govxp", src)

-- ============================================================
-- PREPARAÇÃO DAS TABELAS NO BANCO DE DADOS
-- ============================================================
vRP.Prepare("govxp/create_stolen_table", [[
    CREATE TABLE IF NOT EXISTS gov_stolen (
        plate VARCHAR(50) PRIMARY KEY,
        passport INT(11),
        model VARCHAR(50),
        date INT(20)
    )
]])

-- Tabela adaptada para o padrão existente da sua base (user_id e created_at)
vRP.Prepare("govxp/create_accounts_table", [[
    CREATE TABLE IF NOT EXISTS gov_accounts (
        user_id INT(11) PRIMARY KEY,
        password VARCHAR(255) NOT NULL,
        created_at INT(20) NOT NULL
    )
]])

-- Queries de conta agora buscam e inserem usando 'user_id' e preenchendo o 'created_at'
vRP.Prepare("govxp/get_account", "SELECT * FROM gov_accounts WHERE user_id = @passport")
vRP.Prepare("govxp/add_account", "INSERT INTO gov_accounts (user_id, password, created_at) VALUES (@passport, @password, @created_at)")

vRP.Prepare("govxp/get_all_stolen", "SELECT * FROM gov_stolen")
vRP.Prepare("govxp/add_stolen", "INSERT INTO gov_stolen (plate, passport, model, date) VALUES (@plate, @passport, @model, @date)")
vRP.Prepare("govxp/rem_stolen", "DELETE FROM gov_stolen WHERE plate = @plate")

vRP.Prepare("govxp/get_vehicles", "SELECT * FROM vehicles WHERE Passport = @Passport")
vRP.Prepare("govxp/get_propertys", "SELECT * FROM propertys WHERE Passport = @Passport")
vRP.Prepare("govxp/get_apartments", "SELECT * FROM apartments WHERE Passport = @Passport")

-- Query que busca as informações de piloto na tabela do seu script de aviação
vRP.Prepare("govxp/get_anac", "SELECT * FROM aviacao_pilotos WHERE passport = @passport")

-- ============================================================
-- INICIALIZAÇÃO E SINCRONIZAÇÃO
-- ============================================================
Citizen.CreateThread(function()
    vRP.Query("govxp/create_stolen_table")
    vRP.Query("govxp/create_accounts_table")
    
    Citizen.Wait(1000)
    
    local stolenData = vRP.Query("govxp/get_all_stolen")
    local syncTable = {}
    
    for _, v in pairs(stolenData) do 
        syncTable[v.plate] = true 
    end
    
    GlobalState.StolenPlates = syncTable
    print("^2[Gov.xp] Banco de dados e Radar Global sincronizados com sucesso.^7")
end)

-- ============================================================
-- LÓGICA DE SESSÃO E ANAC
-- ============================================================
function src.getUserInfo()
    local source = source
    local Passport = vRP.Passport(source)
    
    if Passport then
        local fullName = vRP.FullName(Passport) or "Cidadão"
        
        -- Verifica se tem senha
        local account = vRP.Query("govxp/get_account", { passport = Passport })
        local hasAccount = false
        if #account > 0 then
            hasAccount = true
        end
        
        -- Verifica licença da ANAC
        local anacData = vRP.Query("govxp/get_anac", { passport = Passport })
        local pilotInfo = nil
        
        if #anacData > 0 then
            pilotInfo = {
                anac_id = anacData[1].anac_id,
                horas = anacData[1].horas_voo,
                reputacao = anacData[1].reputacao
            }
        end
        
        local currentStatus = "sem_conta"
        if hasAccount then
            currentStatus = "tem_conta"
        end
        
        return { 
            passport = Passport, 
            name = fullName, 
            status = currentStatus,
            anac = pilotInfo
        }
    end
    
    return { 
        passport = 0, 
        name = "Desconhecido", 
        status = "sem_conta" 
    }
end

-- ============================================================
-- LÓGICA DE REGISTRO E LOGIN
-- ============================================================
function src.register(pass)
    local source = source
    local Passport = vRP.Passport(source)
    
    if Passport and pass then
        vRP.Query("govxp/add_account", { 
            passport = Passport, 
            password = pass,
            created_at = os.time() 
        })
        return true
    end
    
    return false
end

function src.login(pass)
    local source = source
    local Passport = vRP.Passport(source)
    
    if Passport then
        local account = vRP.Query("govxp/get_account", { passport = Passport })
        
        if #account > 0 and account[1].password == pass then
            return { success = true }
        else
            return { success = false, error = "Senha incorreta!" }
        end
    end
    
    return { success = false, error = "Sessão inválida!" }
end

-- ============================================================
-- LÓGICA DE VEÍCULOS E ROUBOS
-- ============================================================
function src.getVehicles()
    local source = source
    local Passport = vRP.Passport(source)
    local myVehicles = {}

    if Passport then
        local consult = vRP.Query("govxp/get_vehicles", { Passport = Passport })
        local stolenData = vRP.Query("govxp/get_all_stolen")
        local stolenMap = {}
        
        for _, s in pairs(stolenData) do 
            stolenMap[s.plate] = s.date 
        end
        
        for _, v in pairs(consult) do
            local expired = false
            local days = 0
            local taxAmount = 1500

            local vehSpawn = v.vehicle or v.Vehicle or v.name or v.Name or "Desconhecido"
            local vehPlate = v.plate or v.Plate or "S/PLACA"
            local vTax = v.tax or v.Tax

            local vehRealName = vehSpawn
            if VehicleName then 
                vehRealName = VehicleName(vehSpawn) or vehSpawn 
            end

            if vTax then
                if os.time() > vTax then 
                    expired = true 
                else 
                    days = math.floor((vTax - os.time()) / 86400) 
                end
            else 
                days = 30 
            end

            local cleanPlate = string.gsub(vehPlate, "%s+", "")
            local isStolen = false
            local stolenDate = 0
            
            if stolenMap[cleanPlate] then
                isStolen = true
                stolenDate = stolenMap[cleanPlate]
            end

            table.insert(myVehicles, {
                model = vehRealName,
                plate = vehPlate,
                expired = expired,
                days = days,
                taxAmount = taxAmount,
                isStolen = isStolen,
                stolenDate = stolenDate
            })
        end
    end
    
    return myVehicles
end

function src.reportStolen(plate, model)
    local source = source
    local Passport = vRP.Passport(source)
    
    if Passport then
        local cleanPlate = string.gsub(plate, "%s+", "")
        
        vRP.Query("govxp/add_stolen", { 
            plate = cleanPlate, 
            passport = Passport, 
            model = model, 
            date = os.time() 
        })
        
        local syncTable = GlobalState.StolenPlates or {}
        syncTable[cleanPlate] = true
        GlobalState.StolenPlates = syncTable
        
        return true
    end
    
    return false
end

function src.removeStolen(plate)
    local source = source
    local Passport = vRP.Passport(source)
    
    if Passport then
        local cleanPlate = string.gsub(plate, "%s+", "")
        
        vRP.Query("govxp/rem_stolen", { 
            plate = cleanPlate 
        })
        
        local syncTable = GlobalState.StolenPlates or {}
        syncTable[cleanPlate] = nil
        GlobalState.StolenPlates = syncTable
        
        return true
    end
    
    return false
end

-- ============================================================
-- LÓGICA DE PROPRIEDADES (CASAS/APTOS)
-- ============================================================
function src.getProperties()
    local source = source
    local Passport = vRP.Passport(source)
    local myProps = {}

    if Passport then
        local propertys = vRP.Query("govxp/get_propertys", { Passport = Passport })
        for _, v in pairs(propertys) do
            local expired = false
            local days = 0
            
            if v.Tax and os.time() > v.Tax then 
                expired = true 
            elseif v.Tax then 
                days = math.floor((v.Tax - os.time()) / 86400) 
            end
            
            table.insert(myProps, { 
                name = v.Name or "Casa", 
                type = "Casa", 
                expired = expired, 
                days = days, 
                taxAmount = 850 
            })
        end
        
        local apartments = vRP.Query("govxp/get_apartments", { Passport = Passport })
        for _, v in pairs(apartments) do
            local expired = false
            local days = 0
            
            if v.Tax and os.time() > v.Tax then 
                expired = true 
            elseif v.Tax then 
                days = math.floor((v.Tax - os.time()) / 86400) 
            end
            
            table.insert(myProps, { 
                name = v.Name or "Apartamento", 
                type = "Apartamento", 
                expired = expired, 
                days = days, 
                taxAmount = 1200 
            })
        end
    end
    
    return myProps
end