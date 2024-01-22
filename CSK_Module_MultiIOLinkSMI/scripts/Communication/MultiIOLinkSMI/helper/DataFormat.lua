local format_0 = {
  Name = 'param1',
  index = 0,
  subindex = 0,
  Datatype = {
    type = "UintegerT",
    bitLength = 8
  }
}

local format_1 = {
  Name = 'param1',
  index = 0,
  subindex = 0,
  Datatype = {
    type = "RecordT",
    RecordItem = {
      bitOffset = 24,
      subindex = 1,
      Datatype = {
        type = "UintegerT",
        bitLength = 8
      }
    }
  }
}

local format_2 = {
  Name = 'param1',
  index = 0,
  subindex = 0,
  Datatype = {
    type = "ArrayT",
    count = 3,
    Datatype = {
      type = "UintegerT",
      bitLength = 8
    }
  }
}