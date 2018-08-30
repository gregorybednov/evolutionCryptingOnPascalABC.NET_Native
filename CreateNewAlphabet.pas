var
  LENGTH_OF_ALPHABET, LENGTH_OF_SYMBOL_IN_BITS: integer;
  s:string;
  t: file;
  b:byte;
begin
  write('Введите имя файла, в которое сохранять: ');
  readln(s);
  write('Введите длины алфавита, символов: ');
  read(LENGTH_OF_ALPHABET);
  write('Введите длину символа, бит: ');
  read(LENGTH_OF_SYMBOL_IN_BITS);
  
  if s='' then s:='2.balph';
  if not fileExists(s) then
  begin
  assign(t,s);
  rewrite(t);
  t.Reset();
  write(t, LENGTH_OF_ALPHABET,LENGTH_OF_SYMBOL_IN_BITS);
  loop LENGTH_OF_ALPHABET do
    loop LENGTH_OF_SYMBOL_IN_BITS div 8 do
    begin
      b:=random(256);
      write(t,b);
    end;
  close(t);
  writeln('Запись в файл завершена успешно');
  end
  else begin
  writeln('Вы уверены, что хотите перезаписи файла? Удалите файл вручную, пожалуйста');
  end;
end.