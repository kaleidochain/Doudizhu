local eth = require("eth")

local RegisterAddr = "1000000000000000000000000000000000000003"
local RegisterABI = "[{\"constant\":true,\"inputs\":[{\"name\":\"_name\",\"type\":\"string\"}],\"name\":\"get\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}]"
local register = eth.contract(RegisterABI, RegisterAddr)

function getAddr(register, name)
  local addr = register.Call("get", name)
  print(name .. " addr = " .. addr:sub(3):lower())
  return addr
end

DDZRoomManagerAddr = getAddr(register, "CroomManagerdev")
--notaryAddr = getAddr(register, "NotaryManager")
