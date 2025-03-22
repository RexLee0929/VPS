////////////////////////////////////////////////////////////////////////////////
// 在 ReNamer 中使用 Pascal 脚本来对文件名首个数字+1
////////////////////////////////////////////////////////////////////////////////
var
  i, NumStart, NumEnd, NumLen, Number: Integer;
  Prefix, NumStr, Suffix, NewNumStr: WideString;
begin
  NumStart := -1;

  // 跳过临时前缀“_tmp_”，查找第一个数字
  for i := 6 to Length(FileName) do // '_tmp_'长度为5，从第6位开始查找
  begin
    if IsWideCharDigit(FileName[i]) then
    begin
      NumStart := i;
      break;
    end;
  end;

  if NumStart = -1 then exit; // 无数字则退出

  NumEnd := NumStart;
  while (NumEnd <= Length(FileName)) and IsWideCharDigit(FileName[NumEnd]) do
    Inc(NumEnd);

  Prefix := Copy(FileName, 6, NumStart - 6); // 跳过'_tmp_'取前缀
  NumStr := Copy(FileName, NumStart, NumEnd - NumStart);
  Suffix := Copy(FileName, NumEnd, Length(FileName) - NumEnd + 1);

  NumLen := Length(NumStr); // 严格保留原数字长度
  Number := StrToIntDef(NumStr, 0);
  Inc(Number);

  // 将数字转为字符串
  NewNumStr := IntToStr(Number);

  // 如果长度超出原数字长度，则直接使用新数字不截取
  if Length(NewNumStr) < NumLen then
    while Length(NewNumStr) < NumLen do
      NewNumStr := '0' + NewNumStr;

  FileName := Prefix + NewNumStr + Suffix;
end.
