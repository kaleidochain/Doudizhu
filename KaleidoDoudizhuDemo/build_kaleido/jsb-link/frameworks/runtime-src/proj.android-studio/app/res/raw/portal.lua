local eth = require("eth")
local ge = require("gameengine")
local PortalAddr = "0x43c169fd58af2267fffeb8db00ec6b4cd253c83e"
local PortalABI = "[{\"constant\":true,\"inputs\":[],\"name\":\"promoToken\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"gameToken\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"gameContract\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"fallback\"},{\"constant\":false,\"inputs\":[{\"name\":\"addr\",\"type\":\"address\"}],\"name\":\"setgameContract\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"addr\",\"type\":\"address\"}],\"name\":\"setpromoToken\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"addr\",\"type\":\"address\"}],\"name\":\"setgameToken\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_type\",\"type\":\"string\"},{\"name\":\"_name\",\"type\":\"string\"},{\"name\":\"_version\",\"type\":\"string\"},{\"name\":\"_bootfile\",\"type\":\"string\"}],\"name\":\"setLua\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_type\",\"type\":\"string\"}],\"name\":\"name\",\"outputs\":[{\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_type\",\"type\":\"string\"}],\"name\":\"version\",\"outputs\":[{\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_type\",\"type\":\"string\"}],\"name\":\"bootfile\",\"outputs\":[{\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_type\",\"type\":\"string\"}],\"name\":\"vhash\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_type\",\"type\":\"string\"},{\"name\":\"_filename\",\"type\":\"string\"},{\"name\":\"_txhash\",\"type\":\"string\"}],\"name\":\"setfile\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_type\",\"type\":\"string\"},{\"name\":\"_filename\",\"type\":\"string\"}],\"name\":\"txhashs\",\"outputs\":[{\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_type\",\"type\":\"string\"}],\"name\":\"length\",\"outputs\":[{\"name\":\"\",\"type\":\"uint64\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_type\",\"type\":\"string\"},{\"name\":\"_index\",\"type\":\"uint256\"}],\"name\":\"filebyindex\",\"outputs\":[{\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}]"

local portal = eth.contract(PortalABI, PortalAddr)

function getAddr(portal, name)
  local addr = portal.Call(name)
  print(name .. " addr = " .. addr:sub(3):lower())
  return addr
end


DDZRoomManagerAddr =  getAddr(portal, "gameContract")  -- portal.Call("gameContract")      
btAddr = getAddr(portal,"gameToken")  -- portal.Call("gameToken") 
promotAddr = getAddr(portal,"promoToken") -- portal.Call("promoToken") 

function downLoadScript(path, version)
  
  local err = ge.Mkdir(path)
  if err ~= nil then 
    error(err)
  end   


  local length = portal.Call("length", "gameLua")
  print("length:", length)
  for index=0, length-1 do
    print("index:",index) 
    local filename = portal.Call("filebyindex", "gameLua", index) 
    print("filename:", filename)
    local tx = portal.Call("txhashs", "gameLua", filename)
    print("tx:", tx)
    local fileConten = eth.TransactionPayLoad(tx) 
    local uncompressData , err = ge.ZlibUncompress(fileConten)
    if err ~= nil then 
      ge.RemovePath(path)
      error(err)
    end 

    local luafile = ge.FilePathJoint(path,filename) 
    local err  = ge.WriteFile(luafile, uncompressData)
    if err ~= nil then 
      ge.RemovePath(path)
      error(err)
    end
  end

  local versionFile = ge.FilePathJoint(path, "Version.txt")
  local bversion = byteSlice.new() 
  bversion:appendString(version)
  local err = ge.WriteFile(versionFile, bversion)
  if err ~= nil then 
    ge.RemovePath(path)
    error(err)
  end

end

function PortalStart( )
  local  gameName = portal.Call("name", "gameLua")
  print("gameName:", gameName)

  local  version = portal.Call("version", "gameLua")
  print("Version:", version)

  local  versionHash = portal.Call("vhash", "gameLua")
  print("Version Hash:", versionHash) 

  local versionH = version .."_".. versionHash 

  print("Version + Hash", versionH )

  local  stateDir, err  = ge.StateDir()
  if err ~= nil then 
    error(err)
  end 

  local GameDir = ge.FilePathJoint(stateDir, gameName)

  local Exitflag  = ge.DirExit(GameDir)

  if Exitflag == true then 
    print("exitFlag true", GameDir)
    local  localversion = ge.ScriptVersion("Version.txt", GameDir)
    print("local version", localversion)
  
    if localversion ~= versionH then 
      print("version not equal")
      local err = ge.RemovePath(GameDir)
      --print("remove path:", err)
      downLoadScript(GameDir, versionH)
    else 
      print("version  equal") 
    end
  
  else 
    print("exitFlag false",GameDir)
    downLoadScript(GameDir, versionH)
  end

  ge.SetGameEnvironment(DDZRoomManagerAddr, GameDir)
end


PortalStart() 


require("game")



