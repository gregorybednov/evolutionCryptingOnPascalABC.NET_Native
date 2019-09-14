///Модуль работы с алгоритмом шифрования версии 2.0
///(отличается использованием криптослучайных чисел)
///Реализует все или почти все необходимые для работы
///функции.
unit CryptingCore2;
{$copyright (c) IDIUAM, 2018}
{$string_nullbased+}

interface

///Загружает шифровку в модуль.
procedure LoadMessageToModule(d: array of byte);

///Основная расшифровывающая функция.
///Откатит предыдущую попытку расшифровать текст (нужно, если она была неудачной), если cancelPrevoiusUnciphering будет true
function Uncipher(cancelPrevoiusUnciphering: boolean): string;

///Пытается создать новый алфавит и записать его в файл
///Возвращает -1, если имя файла занято.
///Возвращает 1, если количество бит не делится на 8 нацело. 
///В случае успеха возвращает 0.
function NewRandomAlphabet(fileName: string; bit_lengthSymbol, lengthAlphabet: integer): integer;

///Указывает, что на позиции pos в сообщениях букву следует читать как букву should_read_as
///Возвращает -1, если такой литеры нет в подгруженных словарях (не добавляет инструкцию)
///Возвращает 0, если символ успешно добавлен
///Возвращает 1, если уже были указания по этому символу (но инструкцию добавит)
function AddEdit(pos: integer; should_read_as: char): integer;

///Загружает алфавит с именем fileName. Бинарный формат!
///Возвращает 0 в случае удачи и -1 в случае отсутствия файла
function LoadAlphabet(name: string): integer;

///Загружает словарь с именем fileName.
///Возвращает 0 при удаче, -1 - если такого файла не найдено
function LoadDict(fileName: string): integer;

///Удаляет весь список редакций. Настоятельно рекомендуется использовать при загрузках новых шифровок
procedure EraseAllEdits();

///Основная шифрующая функция. Возвращает массив байт, готовую шифровку
function Cipher(s: string): array of byte;

///Сохраняет уже открытый алфавит с заменой имеющегося. Бинарный файл!
///Возвращает 0, если всё прошло успешно
///Возвращает -1, если неудача
function SaveAlphabet(): integer;


implementation

type
  BitArray = System.Collections.BitArray;

var
  ///Шифроалфавит (или просто алфавит). Является основой шифрования
  ///и дешифрования в алгоритме.
  ///Загружается процедурой LoadAlphabet(), сохраняется процедурой
  ///SaveAlphabet().
  alphabet: array of BitArray;
  
  ///Копия алфавита для откатов "неудачных" обучений...
  reservedAlphabet: array of BitArray;
  
  ///Словарь для ассоциации символа с номером шифросимвола в алфавите.
  avdict := new Dictionary<Char, Integer>;
  
  ///Словарь для ассоциации номера шифросимвола в алфавите с символом
  revdict := new Dictionary<Integer, Char>;
  
  ///Имя файла с алфавитом
  fileName: string;
  
  ///Длина шифросимвола в битах. Должна делиться на 8 нацело.
  LENGTH_OF_SYMBOL: integer = 1000;
  
  ///Количество шифросимволов в алфавите
  LENGTH_OF_ALPHABET: integer = 168;
  
  ///Количество мутаций в алфавите
  MUTATIONS: integer = LENGTH_OF_SYMBOL div 7;
  
  edits := new Dictionary<integer, Char>;
  message: array of byte;
  
  ///сюда класть криптостойкие шифры
  randBytes: array of byte;
  
  ///позиция на криптостойких байтах
  posRand: integer = 0;

function randomInteger(upperBound: integer): integer;
begin
  result := (randBytes[posRand] shl 8 + randBytes[posRand + 1]) mod upperBound;
  posRand += 2;  
end;

///Удаляет весь список редакций. Настоятельно рекомендуется использовать при загрузках
///новых шифровок
procedure EraseAllEdits();
begin
  edits.Clear();
end;

///Делает MUTATIONS мутаций в алфавите
procedure randmutations();
var
  randX, randQ: integer;
begin
  loop MUTATIONS do begin//Count раз   
    randQ := randomInteger(LENGTH_OF_ALPHABET);//выбираем случайный бит в алфавите
    randX := randomInteger(LENGTH_OF_SYMBOL);
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

///Основная шифрующая функция. Возвращает массив байт,
///готовую шифровку
function Cipher(s: string): array of byte;
var
  ///отдельный шифросимвол
  liter: BitArray = new BitArray(LENGTH_OF_SYMBOL);
  
  ///криптостойкий генератор псевдослучайных чисел
  rng: System.Security.Cryptography.RNGCryptoServiceProvider = new System.Security.Cryptography.RNGCryptoServiceProvider();

begin
  setlength(randBytes, 0);
  setlength(randBytes, (2 * MUTATIONS * s.Length + 1) * sizeof(integer));
  rng.GetBytes(randBytes);
  posRand := 0;
  
  setlength(result, s.Length * LENGTH_OF_SYMBOL div 8 + randomInteger(LENGTH_OF_SYMBOL div 8));//выделить место под результат
  
  for var q := 0 to s.Length - 1 do//для каждого символа строки...
  begin
    liter := alphabet[avdict[s[q]]];//сделать соответствующий символ
    liter.CopyTo(result, q * LENGTH_OF_SYMBOL div 8);//внести в массив байт
    randmutations();//изменение алфавита при шифровании
  end;
  
  rng.GetBytes(result,s.Length*LENGTH_OF_SYMBOL div 8,result.Length-s.Length * LENGTH_OF_SYMBOL div 8);
end;

///Загружает шифровку в модуль.
procedure LoadMessageToModule(d: array of byte);
begin
  message := copy(d);
end;

///Основная расшифровывающая функция.
///Откатит предыдущую попытку расшифровать текст (нужно, если она была неудачной),
///если cancelPrevoiusUnciphering будет true
function Uncipher(cancelPrevoiusUnciphering: boolean): string;
var
  w: uint64 = 0;//счётчик по битам
  num: integer;//выявленный номер шифросимвола
  j0: integer;//счётчик по выполненным запросам
begin
  if cancelPrevoiusUnciphering//если сказано откатать предыдущее обучение по расшифрованию
    then alphabet := copy(reservedAlphabet)//то откатываем
  else reservedAlphabet := copy(alphabet);//иначе - резервируем новую версию
  result := '';//строка с результатом. Пока пустая.
  j0 := 0;
  while w + LENGTH_OF_SYMBOL div 8 <= message.Length do begin
    var u := new BitArray(message[w:w + LENGTH_OF_SYMBOL div 8]);//отдельный шифросимвол
    if (edits.ContainsKey(j0)) then begin//если ещё не все запросы обработаны и смотреть на последний, если совпадает
      num := avdict[edits[j0]];//номер определить принудительно
    end else num := theSamestLiter(u);//иначе автоматически определяем номер этого шифросимвола 
    alphabet[num] := u;//"обучаем" новому виду буквы
    result += revdict[num];//записываем букву-результат
    w += LENGTH_OF_SYMBOL div 8;//тик счётчика (по битам)
    j0 += 1; //тик счётчика (по символам)
  end;
end;

///Сохраняет уже открытый алфавит с заменой имеющегося. Бинарный файл!
///Возвращает 0, если всё прошло успешно
///Возвращает -1, если неудача
function SaveAlphabet(): integer;
var
  t: file;
begin
  if fileExists(fileName) then begin
    rewrite(t, fileName);//переписать файл
    write(t, LENGTH_OF_ALPHABET, LENGTH_OF_SYMBOL);//вписать: длину алфавита (4 байта, знаковый), длину символа в битах (4 байта, знаковый)
    
    var bytes: array of byte;                                     //
    setlength(bytes, LENGTH_OF_ALPHABET * LENGTH_OF_SYMBOL div 8);//сковертировать array of BitArray в array of byte
    for var q := 0 to alphabet.Length - 1 do                      //для удобной и быстрой записи 
      alphabet[q].CopyTo(bytes, q * LENGTH_OF_SYMBOL div 8);      //
    
    for var i := 0 to bytes.Length - 1 do//для каждого полученного байта
      write(t, bytes[i]);//записать в файл (1 байт, беззнаковый)
    close(t);//закрыть файл
    result := 0;
  end
  else result := -1;
end;

///Загружает алфавит с именем fileName. Бинарный формат!
///Возвращает 0 в случае удачи и -1 в случае отсутствия файла
function LoadAlphabet(name: string): integer;
var
  t: file;
  p, m: integer;
  bytes: array of array of byte;
begin
  if fileExists(name) then begin
    fileName:=name;
    assign(t, fileName);//ассоциировать имя файла
    Reset(t);//загрузить для чтения
    read(t, p, m);//прочитать два числа (4 байта, знаковые)
    LENGTH_OF_ALPHABET := p;//первое число - длина алфавита
    MUTATIONS := LENGTH_OF_ALPHABET div 7;
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
    fileName := name;
    result := 0;
    reservedAlphabet := copy(alphabet);
  end
  else result := -1;
end;

///Загружает словарь с именем fileName.
///Возвращает 0 при удаче, -1 - если такого файла не найдено
function LoadDict(fileName: string): integer;
var
  t: Text;
  c: char;
  i: integer = 0;
begin
  if fileExists(fileName) then begin//если имеется файл..
    reset(t, fileName);        //то открыть его
    
    avdict.Clear();              // по-хорошему, нет смысла иметь более 1 загруженного словаря
    revdict.Clear();           // (неоднозначность по char'ам устранима, а по номерам... чуть сложнее)
    
    while not t.Eof do begin//пока не закончится...
     read(t, c);     //читать по символу
      
      if not avdict.ContainsKey(c) then begin //если такой символ уже есть...
        avdict.Add(c, i);                  //добавить в словари
        revdict.Add(i, c);
        i += 1;//тик счетчика по номерам
      end;
    end;
    close(t);//закрыть файл
    result := 0;  end else result := -1;
end;

///Пытается создать новый алфавит и записать его в файл
///Возвращает -1, если имя файла занято.
///Возвращает 1, если количество бит не делится на 8 нацело. 
///В случае успеха возвращает 0.
function newRandomAlphabet(fileName: string; bit_lengthSymbol, lengthAlphabet: integer): integer;
var
  t: file;
begin
  setlength(randBytes,0);
  setlength(randBytes,lengthAlphabet*bit_lengthSymbol div 8);
  var rng:=new System.Security.Cryptography.RNGCryptoServiceProvider();
  rng.GetBytes(randBytes);
  if not fileExists(fileName) then 
  begin
    if (bit_lengthSymbol mod 8) = 0 then begin
      assign(t, fileName);//открываем файл
      rewrite(t);
      t.Reset();
      
      write(t, lengthAlphabet, bit_lengthSymbol);//записываем длину алфавита (4 байта, знаковый) и длину шифросимвола в битах (4 байта, знаковый)
      
      for var i:=0 to randBytes.Length-1 do write(t, randBytes[i]); //заполнить файл случайными байтами      
      close(t);//закрыть файл
      
      result := 0;//вернуть 0, что всё прошло успешно
    end else result := 1;
  end
  else result := -1;
end;

///Указывает, что на позиции pos в сообщениях букву следует читать как букву should_read_as
///Возвращает -1, если такой литеры нет в подгруженных словарях (не добавляет инструкцию)
///Возвращает 0, если символ успешно добавлен
///Возвращает 1, если уже были указания по этому символу (но инструкцию добавит)
function addEdit(pos: integer; should_read_as: char): integer;
begin
  if avdict.ContainsKey(should_read_as) then begin
    if edits.ContainsKey(pos) then begin
      edits[pos] := should_read_as;
      result := 1;
    end else begin
      edits.Add(pos, should_read_as);
      result := 0;
    end; end 
  else result := -1;
end;
end.