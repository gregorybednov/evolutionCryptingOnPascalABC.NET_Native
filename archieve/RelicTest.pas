{$apptype windows}
{$reference System.Windows.Forms.dll}
{$version 2.3}
{$product RelicOfLiberty}
{$copyright (c) IDIUAM, 2018}
{$string_nullbased+}
type
BitArray=System.Collections.BitArray;
Form=System.Windows.Forms.Form;
Button=System.Windows.Forms.Button;
RichTextBox=System.Windows.Forms.RichTextBox;
OpenFileDialog=System.Windows.Forms.OpenFileDialog;
TextBox=System.Windows.Forms.TextBox;

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
  
  ///Порт для передачи информации. Значение зависит от выбранной "полярности".
  port1: integer;
  
  ///Порт для приёма информации. Значение зависит от выбранной "полярности".
  port2: integer;
  
  {ПЕРЕМЕННЫЕ ПОЛЬЗОВАТЕЛЬСКОГО ИНТЕРФЕЙСА}
  mainform := new Form();
  mytextbox := new RichTextBox();
  theirtextbox := new RichTextBox;
  sendbutton := new Button();
  IPv6 := new TextBox();
  слушатьКнопка := new Button();
  подпись := new System.Windows.Forms.Label();
  кнопка1 := new Button();
  кнопка2 := new Button();
  подписьВхода := new System.Windows.Forms.Label();
  кнопкаОткрытьСловарь := new Button();
  кнопкаОткрытьАлфавит := new Button();
  диалоговое1 := new OpenFileDialog();
  диалоговое2 := new OpenFileDialog();
  
  ///True, пока приложение не закрывается
  g: boolean = true;
  {КОНЕЦ ОПИСАНИЯ ПЕРЕМЕННЫХ ДЛЯ ПОЛЬЗОВАТЕЛЬСКОГО ИНТЕРФЕЙСА}
  
  {ТЕСТОВЫЕ ПЕРЕМЕННЫЕ}
  ///массив со статистикой по встречаемости байтов
  o:array [0..255] of uint64;
  {КОНЕЦ ОПИСАНИЯ ТЕСТОВЫХ ПЕРЕМЕННЫХ}
  
///Делает Count мутаций в алфавите
procedure randmutations(Count: integer);
var
  randX,randQ: integer;
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
function byteArray(s: string): array of byte;
var
  ///отдельный шифросимвол
  liter := new BitArray(LENGTH_OF_SYMBOL);
begin
  
  setlength(result, s.Length * LENGTH_OF_SYMBOL div 8+random(LENGTH_OF_SYMBOL div 8));//выделить место под результат
  
  for var q := 0 to s.Length - 1 do//для каждого символа строки...
  begin
    liter := alphabet[dict[s[q]]];//сделать соответствующий символ
    liter.CopyTo(result, q * LENGTH_OF_SYMBOL div 8);//внести в массив байт
    randmutations(LENGTH_OF_SYMBOL div 3);//изменение алфавита при шифровании
  end;
  
  for var w := s.Length * LENGTH_OF_SYMBOL div 8 to result.Length - 1 do //внести хвост из "лишних" байт
  begin
    result[w] := random(256);
  end;
end;

///Основная расшифровывающая функция
function uncypher(t: array of byte): string;
var
  w: uint64 = 0;//счётчик
  num: integer;//выявленный номер шифросимвола
begin
  result := '';//строка с результатом. Пока пустая.
  while w + LENGTH_OF_SYMBOL div 8 <= t.Length do 
  begin
    var u:=new BitArray(t[w:w+LENGTH_OF_SYMBOL div 8]);//отдельный шифросимвол    
    num := theSamestLiter(u);//определяем номер этого шифросимвола
    alphabet[num]:=u;//"обучаем" новому виду буквы
    result += revdict[num];//записываем букву-результат
    w += LENGTH_OF_SYMBOL div 8;//тик счётчика
  end;
end;

procedure RunServer(OnProcessCommand: string -> ());
var
  w: array of byte;
  lng: uint64;
begin
  var server := new System.Net.Sockets.TcpListener(System.Net.IPAddress.IPv6Any, port2);
  server.Start();
  var client := server.AcceptTcpClient();
  var stream := client.GetStream();
  var br := new System.IO.BinaryReader(stream);
  lng := br.ReadInt64();
  w := br.ReadBytes(lng);
  for var i:=0 to w.Length-1 do o[w[i]]+=1;
  for var i:=0 to 255 do
  writeln(o[i]);
  br.Close();
  stream.Close();
  client.Close();
  var data := uncypher(w);
  OnProcessCommand(data);
  server.Stop();
end;

procedure ProcessCommand(info: string);
begin
  case info of//скан на внутренние команды. остались с консольной версии.
    'ENDEXITSTOP':
      begin
        theirtextbox.Text := 'Диалог закончен, сейчас произойдёт завершение работы программы';
        sleep(1000);
        halt();
      end;
    'CLRSCR':
      begin
        theirtextbox.Text := 'Через 2 сек экран сейчас будет очищен';
        sleep(2000);
        theirtextbox.Text := '';
      end;
  else theirtextbox.Text := info;
  end;
end;

procedure SendMessage(Sender: Object; Args: System.EventArgs);
var
  results: array of byte;
  s: string;
  i: integer;
begin
  s := mytextbox.Text;
  while i < s.Length do
  begin
    if not dict.ContainsKey(s[i]) then delete(s, i, 1) else i += 1;
  end;
  try
    var client := new System.Net.Sockets.TcpClient(IPv6.Text, port1);
    var stream := client.GetStream();
    var bw := new System.IO.BinaryWriter(stream);
    results := byteArray(mytextbox.Text);
    bw.Write(results.LongLength);
    bw.Write(results);
    bw.Flush();
    stream.Close();
    client.Close();
  except
    on System.Net.Sockets.SocketException do theirtextbox.Text := '[ИЗВИНИТЕ, ЧТО-ТО НЕ ТАК СО СВЯЗЬЮ С СОБЕСЕДНИКОМ]';
  end;
end;

///процедура сохранения алфавита. Сохраняет алфавит именем fileName с заменой имеющегося. Бинарный файл!
procedure saveAlphabet(fileName: string);
var
  t: file;
begin
  rewrite(t, fileName);//переписать файл
  write(t, LENGTH_OF_ALPHABET, LENGTH_OF_SYMBOL);//вписать: длину алфавита (4 байта, знаковый), длину символа в битах (4 байта, знаковый)
  
  var bytes:array of byte;                                      //
  setlength(bytes,LENGTH_OF_ALPHABET*LENGTH_OF_SYMBOL div 8);   //сковертировать array of BitArray в array of byte
  for var q := 0 to alphabet.Length - 1 do                      //для удобной и быстрой записи 
    alphabet[q].CopyTo(bytes,q*LENGTH_OF_SYMBOL div 8);         //
    
  for var i := 0 to bytes.Length-1 do//для каждого полученного байта
    write(t,bytes[i]);//записать в файл (1 байт, беззнаковый)
  close(t);//закрыть файл
end;

///Выполняется при завершении программы; сохраняет алфавит, обрывает ожидание соединения или само соединение
procedure StopProgram(Sender: Object; Args: System.EventArgs);
begin
  g := false;
  if fileExists(fileName) then saveAlphabet(fileName);
end;

///Включает прослушивание в Интернет
procedure ListenNow(Sender: Object; Args: System.EventArgs);
begin
  слушатьКнопка.Enabled := false;//запрет создавать другие потоки для прослушивания
  var t := new System.Threading.Thread(procedure->begin while (g) do RunServer(ProcessCommand); end);//новый поток для прослышивания
  t.IsBackground := true;//сделать поток фоновым
  t.Start();//запустить поток
end;

///Назначает номера портов в зависимости от выбранной 
///пользователем "полярности" (какую кнопку нажал, 1ую или 2ую)
procedure Ports(Sender: Object; Args: System.EventArgs);
begin
  if Sender.GetHashCode = кнопка1.GetHashCode then 
  begin
    port1 := 13999;
    port2 := 14000;
  end
  else begin
    port1 := 14000;
    port2 := 13999;
  end;
  mytextbox.Visible := true;
  theirtextbox.Visible := true;
  sendbutton.Visible := true;
  IPv6.Visible := true;
  слушатьКнопка.Visible := true;
  подпись.Visible := true;
  кнопкаОткрытьСловарь.Visible := true;
  кнопкаОткрытьАлфавит.Visible := true;
  кнопка1.Visible := false;
  кнопка2.Visible := false;
  подписьВхода.Visible := false;
end;

///Загружает словарь с именем fileName
procedure loadDict(fileName: string);
var
  t: Text;
  c: char;
  i: integer = 0;
begin
  if fileExists(fileName) then begin
    reset(t, fileName);
    while not t.Eof do
    begin
      read(t, c);
      dict.Add(c, i);
      revdict.Add(i, c);
      i += 1;
    end;
    close(t);
  end;
end;

///Загружает алфавит с именем fileName. Бинарный формат!
procedure loadAlphabet(fileName: string);
var
  t: file;
  p, m: integer;
  bytes: array of array of byte;
begin
  if fileExists(fileName) then begin
    assign(t, fileName);//ассоциировать имя файла
    Reset(t);//загрузить для чтения
    read(t, p, m);//прочитать два числа (4 байта, знаковые)
    LENGTH_OF_ALPHABET := p;//первое число - длина алфавита
    LENGTH_OF_SYMBOL := m;//второе - длина шифросимвола в битах
    m:=m div 8;//а это в байтах
    
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
  end;
end;

///Происходит при нажатии кнопки "Алфавит". Отделена от loadAlphabet() для большей
///гибкости кода: если openAlphabet() сильно привязана к пользовательскому интерфейсу, 
///то loadAlphabet() от него не зависит вовсе
procedure openAlphabet(Sender: Object; Args: System.EventArgs);
begin
  диалоговое1.ShowDialog();
  fileName := диалоговое1.FileName;
  LoadAlphabet(диалоговое1.FileName);
end;

///Происходит при нажатии кнопки "Словарь". Отделена от loadDict() для большей
///гибкости кода: если openDictionary() сильно привязана к пользовательскому интерфейсу, 
///то loadDict() от него не зависит вовсе
procedure openDictionary(Sender: Object; Args: System.EventArgs);
begin
  диалоговое2.ShowDialog();
  LoadDict(диалоговое2.FileName);
end;

begin
  кнопкаОткрытьАлфавит.Visible := false;
  mytextbox.Visible := false;
  theirtextbox.Visible := false;
  sendbutton.Visible := false;
  IPv6.Visible := false;
  слушатьКнопка.Visible := false;
  подпись.Visible := false;
  кнопкаОткрытьСловарь.Visible := false;
  
  подписьВхода.Text := 'Беседовать между собой могут только + и -.';
  подписьВхода.Left := 300;
  подписьВхода.Top := 12;
  подписьВхода.Width := 300;
  подписьВхода.Parent := mainform;
  
  кнопка1.Text := 'Полярность "+"';
  кнопка1.Left := 10;
  кнопка1.Top := 50;
  кнопка1.Height := 400;
  кнопка1.Width := 400;
  
  кнопка2.Text := 'Полярность "-"';
  кнопка2.Left := 450;
  кнопка2.Top := 50;
  кнопка2.Height := 400;
  кнопка2.Width := 400;
  кнопкаОткрытьСловарь.Left := 650;
  кнопкаОткрытьСловарь.Height := 20;
  кнопкаОткрытьАлфавит.Left := 725;
  кнопкаОткрытьАлфавит.Height := 20;
  кнопкаОткрытьСловарь.Text := 'Словарь';
  кнопкаОткрытьАлфавит.Text := 'Алфавит';
  
  кнопкаОткрытьСловарь.Parent := mainform;
  кнопкаОткрытьАлфавит.Parent := mainform;
  кнопка1.Parent := mainform;
  кнопка2.Parent := mainform;
  
  подпись.Top := 55 * 4;
  подпись.Width := 100;
  подпись.Height := 40;
  подпись.Text := 'последнее сообщение собеседника:';
  
  mainform.Text := 'Реликвия';
  sendbutton.Text := 'Отправить!';
  mainform.Height := 55 * 10;mainform.Width := 89 * 10;
  mytextbox.Height := 55 * 3;mytextbox.Width := 89 * 10 - 17;mytextbox.Top := 20;
  theirtextbox.Height := 55 * 3;theirtextbox.Width := 89 * 10 - 17;theirtextbox.Top := 260;
  sendbutton.Height := 8 * 6;sendbutton.Width := 13 * 6;sendbutton.Top := 185;sendbutton.Left := 630;
  //theirtextbox.Enabled := false;
  
  IPv6.Parent := mainform;
  подпись.Parent := mainform;
  IPv6.Width := 250;
  слушатьКнопка.Height := 20;
  слушатьКнопка.Text := 'Слушать в Интернет!';
  слушатьКнопка.Width := 150;
  слушатьКнопка.Left := 500;
  слушатьКнопка.Parent := mainform;
  
  mytextbox.Parent := mainform;
  theirtextbox.Parent := mainform;
  sendbutton.Parent := mainform;
  
  sendbutton.Click += SendMessage;
  слушатьКнопка.Click += ListenNow;
  кнопкаОткрытьАлфавит.Click += openAlphabet;
  кнопкаОткрытьСловарь.Click += openDictionary;
  dict.Clear();
  revdict.Clear();
  кнопка1.Click += Ports;
  кнопка2.Click += Ports;
  mainform.Closed += StopProgram;
  System.Windows.Forms.Application.Run(mainform);
end.