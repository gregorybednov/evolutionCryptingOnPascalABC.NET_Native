library CryptingCore;
//PascalABC.Net, 3.4.0.1670
{$copyright (c) IDIUAM, 2018}
{$string_nullbased+}
interface

///Основная шифрующая функция
function cipher(s: string): array of byte;

///Основная расшифровывающая функция
function uncipher(t: array of byte): string;

///Сохраняет алфавит с заменой загруженного. Используется бинарный формат.
procedure saveAlphabet();

///Загружает алфавит с именем fileName. Используется бинарный формат.
///Возвращает 0 при удаче, -1 если файла с именем fileName не найдено
function loadAlphabet(name: string): integer;

///Загружает словарь с именем fileName.
///Возвращает 0 при удаче, -1 если файла с именем fileName не найдено
function loadDict(fileName: string): integer;

///Пытается создать новый алфавит и записать его в файл
///Возвращает -1, если имя файла занято.
///Возвращает 1, если количество бит не делится на 8 нацело. 
///В случае успеха возвращает 0.
function newRandomAlphabet(fileName: string; bit_lengthSymbol, lengthAlphabet: integer): integer;

implementation

type
  BitArray = System.Collections.BitArray;

var
  ///Шифроалфавит (или просто алфавит). Является основой шифрования
  ///и дешифрования в алгоритме.
  ///Загружается процедурой LoadAlphabet(), сохраняется процедурой
  ///SaveAlphabet().
  alphabet: array of BitArray;
  
  ///Словарь для ассоциации символа с номером шифросимвола в алфавите.
  dict := new Dictionary<Char, Integer>;
  
  ///Словарь для ассоциации номера шифросимвола в алфавите с символом
  revdict := new Dictionary<Integer, Char>;
  
  ///Имя файла с алфавитом
  fileName: string;
  
  ///Длина шифросимвола в битах. Должна делиться на 8 нацело.
  LENGTH_OF_SYMBOL := 1000;
  
  ///Количество шифросимволов в алфавите
  LENGTH_OF_ALPHABET := 168;


  ///Делает Count мутаций в алфавите
procedure randmutations(Count: integer);
var
  randX, randQ: integer;
begin
  loop count do//Count раз
  begin
    
    randQ := random(LENGTH_OF_ALPHABET);//выбираем случайный бит в алфавите
    randX := random(LENGTH_OF_SYMBOL);
    
    alphabet[randQ][randX] := not alphabet[randQ][randX];//и инвертируем этот бит
    
  end;
end;

///Выявляет наиболее похожий символ в алфавите и возвращает его номер
function theSamestLiter(const symbol: BitArray): integer;
var
  whatsthebest: array of longword;
begin
  setlength(whatsthebest, LENGTH_OF_ALPHABET);
  for var q := 0 to LENGTH_OF_ALPHABET - 1 do //для каждого шифросимвола в алфавите
    for var x := 0 to LENGTH_OF_SYMBOL - 1 do //побитно 
      
      if symbol.Get(x) = alphabet[q].Get(x) //сравнить с symbol
        then whatsthebest[q] += 1;
      //минусить если это не так смысла нет (т.к. возможно всего 2 варианта: либо совпадают, либо нет)
  result := whatsthebest.IndexMax();//выбираем лучшее
end;

///Основная шифрующая функция
function cipher(s: string): array of byte;
var
  ///отдельный шифросимвол
  liter := new BitArray(LENGTH_OF_SYMBOL);
begin
  
  setlength(result, s.Length * LENGTH_OF_SYMBOL div 8 + random(LENGTH_OF_SYMBOL div 8));//выделить место под результат
  
  for var q := 0 to s.Length - 1 do//для каждого символа строки...
  begin
    if dict.ContainsKey(s[q]) then //если на такой символ есть шифросимвол, то ...
    begin
      liter := alphabet[dict[s[q]]];//сделать соответствующий символ
      liter.CopyTo(result, q * LENGTH_OF_SYMBOL div 8);//внести в массив байт
      randmutations(LENGTH_OF_SYMBOL div 3);//изменение алфавита при шифровании
    end
    else 
    begin//если нет такого символа, то...
      //пока просто игнорировать
    end;
  end;
  
  for var w := s.Length * LENGTH_OF_SYMBOL div 8 to result.Length - 1 do //внести хвост из "лишних" байт
  begin
    result[w] := random(256);
  end;
end;

///Основная расшифровывающая функция
function uncipher(t: array of byte): string;
var
  w: uint64 = 0;//счётчик
  num: integer;//выявленный номер шифросимвола
begin
  result := '';//строка с результатом. Пока пустая.
  while w + LENGTH_OF_SYMBOL div 8 <= t.Length do 
  begin
    var u := new BitArray(t[w:w + LENGTH_OF_SYMBOL div 8]);//отдельный шифросимвол    
    num := theSamestLiter(u);//определяем номер этого шифросимвола
    alphabet[num] := u;//"обучаем" новому виду буквы
    result += revdict[num];//записываем букву-результат
    w += LENGTH_OF_SYMBOL div 8;//тик счётчика
  end;
end;

///Сохраняет алфавит с заменой имеющегося. Используется бинарный формат.
procedure saveAlphabet();
var
  t: file;
begin
  rewrite(t, fileName);//переписать файл
  write(t, LENGTH_OF_ALPHABET, LENGTH_OF_SYMBOL);//вписать: длину алфавита (4 байта, знаковый), длину символа в битах (4 байта, знаковый)
  
  var bytes: array of byte;                                      //
  setlength(bytes, LENGTH_OF_ALPHABET * LENGTH_OF_SYMBOL div 8);   //сковертировать array of BitArray в array of byte
  for var q := 0 to alphabet.Length - 1 do                      //для удобной и быстрой записи 
    alphabet[q].CopyTo(bytes, q * LENGTH_OF_SYMBOL div 8);         //
  
  for var i := 0 to bytes.Length - 1 do//для каждого полученного байта
    write(t, bytes[i]);//записать в файл (1 байт, беззнаковый)
  close(t);//закрыть файл
end;

///Загружает алфавит с именем mame. Бинарный формат!
///Возвращает 0 при удаче, -1 - если такого файла не найдено
function loadAlphabet(name: string): integer;
var
  t: file;
  p, m: integer;
  bytes: array of array of byte;
begin
  if fileExists(fileName) then begin
    fileName := name;
    assign(t, fileName);//ассоциировать имя файла
    Reset(t);//загрузить для чтения
    read(t, p, m);//прочитать два числа (4 байта, знаковые)
    LENGTH_OF_ALPHABET := p;//первое число - длина алфавита
    LENGTH_OF_SYMBOL := m;//второе - длина шифросимвола в битах
    m := m div 8;//а это в байтах
    
    setlength(bytes, p);//прочтём как массив байт
    for var q := 0 to p - 1 do 
      setlength(bytes[q], m);
    
    setlength(alphabet, 0);//"перезагрузим" алфавит
    setlength(alphabet, p);//
    
    for var q := 0 to p - 1 do//чтение всех байт
      for var u := 0 to m - 1 do
        read(t, bytes[q][u]);
    
    for var q := 0 to p - 1 do//конвертация в алфавит
      alphabet[q] := new BitArray(bytes[q]);
    
    close(t);//закрыть файл
    result := 0;
  end
  else result := -1;
end;

///Загружает словарь с именем fileName.
///Возвращает 0 при удаче, -1 - если такого файла не найдено
function loadDict(fileName: string): integer;
var
  t: Text;
  c: char;
  i: integer = 0;
begin
  if fileExists(fileName) then //если имеется файл..
  begin
    reset(t, fileName);        //то открыть его
    
    dict.Clear();              // по-хорошему, нет смысла иметь более 1 загруженного словаря
    revdict.Clear();           // (неоднозначность по char'ам устранима, а по номерам... чуть сложнее)
    
    while not t.Eof do//пока не закончится...
    begin
      read(t, c);     //читать по символу
      
      if not dict.ContainsKey(c) then  //если такой символ уже есть...
      begin
        dict.Add(c, i);                  //добавить в словари
        revdict.Add(i, c);
        i += 1;//тик счетчика по номерам
      end;
    end;
    close(t);//закрыть файл
    result := 0;
  end
  else
  begin
    result := -1;
  end;
end;

///Пытается создать новый алфавит и записать его в файл
///Возвращает -1, если имя файла занято.
///Возвращает 1, если количество бит не делится на 8 нацело. 
///В случае успеха возвращает 0.
function newRandomAlphabet(fileName: string; bit_lengthSymbol, lengthAlphabet: integer): integer;
var
  t: file;
  b: byte;
begin
  if not fileExists(fileName) then 
  begin
    if (bit_lengthSymbol mod 8) = 0 then 
    begin
      
      assign(t, fileName);//открываем файл
      rewrite(t);
      t.Reset();
      
      write(t, lengthAlphabet, bit_lengthSymbol);//записываем длину алфавита (4 байта, знаковый) и длину шифросимвола в битах (4 байта, знаковый)
      
      loop lengthAlphabet do
        loop bit_lengthSymbol do              //    
        begin// заполнить файл
          b := random(256);                   // случайными байтами 
          write(t, b);                        //
        end;                                  //
      
      close(t);//закрыть файл
      
      result := 0;//вернуть 0, что всё прошло успешно
    end
    else result := 1;
  end
  else result := -1;
end;
end.