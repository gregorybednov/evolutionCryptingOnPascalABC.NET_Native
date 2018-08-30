program CipheringMachine;
uses CryptingCore2;
{$apptype windows}
{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}
{$product ciphering_machine}
{$version 2.5.0}
{$copyright (c) IDIUAM, 2018}
{$string_nullbased+}

type
  Form = System.Windows.Forms.Form;
  Button = System.Windows.Forms.Button;
  RichTextBox = System.Windows.Forms.RichTextBox;
  OpenFileDialog = System.Windows.Forms.OpenFileDialog;
  TextBox = System.Windows.Forms.TextBox;

var
  ///Порт для передачи информации. Значение зависит от выбранной "полярности".
  port1: integer;
  
  ///Порт для приёма информации. Значение зависит от выбранной "полярности".
  port2: integer;
  
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
  correctingLetter := new TextBox();
  ///True, пока приложение не закрывается
  g: boolean = true;

procedure RunServer(OnProcessCommand: string -> ());
var
  lng: uint64;
begin
  var server := new System.Net.Sockets.TcpListener(System.Net.IPAddress.IPv6Any, port2);
  server.Start();
  var client := server.AcceptTcpClient();
  var stream := client.GetStream();
  var br := new System.IO.BinaryReader(stream);
  lng := br.ReadInt64();
  var mesArray := br.ReadBytes(lng);
  CryptingCore2.LoadMessageToModule(mesArray);
  CryptingCore2.EraseAllEdits();
  
  br.Close();
  stream.Close();
  client.Close();
  
  var data := CryptingCore2.Uncipher(false);
  OnProcessCommand(data);
  server.Stop();
end;

procedure ProcessCommand(info: string);
begin
  theirtextbox.Text := info;
end;

procedure SendMessage(Sender: Object; Args: System.EventArgs);
var
  results: array of byte;
  s: string;
begin
  s := mytextbox.Text;
  try
    var client := new System.Net.Sockets.TcpClient(IPv6.Text, port1);
    var stream := client.GetStream();
    var bw := new System.IO.BinaryWriter(stream);
    results := CryptingCore2.Cipher(s);
    bw.Write(results.LongLength);
    bw.Write(results);
    bw.Flush();
    stream.Close();
    client.Close();
  except
    on System.Net.Sockets.SocketException do theirtextbox.Text := '[ИЗВИНИТЕ, ЧТО-ТО НЕ ТАК СО СВЯЗЬЮ С СОБЕСЕДНИКОМ]';
  end;
end;

///Выполняется при завершении программы; сохраняет алфавит, обрывает ожидание соединения или само соединение
procedure StopProgram(Sender: Object; Args: System.EventArgs);
begin
  g := false;
  CryptingCore2.SaveAlphabet();
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
  correctingLetter.Visible := true;
  кнопкаОткрытьСловарь.Visible := true;
  кнопкаОткрытьАлфавит.Visible := true;
  кнопка1.Visible := false;
  кнопка2.Visible := false;
  подписьВхода.Visible := false;
end;

///Происходит при нажатии кнопки "Алфавит". 
procedure openAlphabet(Sender: Object; Args: System.EventArgs);
begin
  диалоговое1.ShowDialog();
  LoadAlphabet(диалоговое1.FileName);
end;

///Происходит при нажатии кнопки "Словарь". 
procedure openDictionary(Sender: Object; Args: System.EventArgs);
begin
  диалоговое2.ShowDialog();
  LoadDict(диалоговое2.FileName);
end;

///Основная процедура коррекции расшифровки
procedure tryToClick(Sender: Object; Args: System.Windows.Forms.MouseEventArgs);
begin
  if correctingLetter.Text.Length > 0 then 
  begin
    var n := theirtextbox.GetCharIndexFromPosition(new System.Drawing.Point(Args.X, Args.Y));
    var c := correctingLetter.Text[0];
    cryptingCore2.AddEdit(n, c);
    theirtextbox.Text := CryptingCore2.Uncipher(true);
  end;
end;


begin
  кнопкаОткрытьАлфавит.Visible := false;
  mytextbox.Visible := false;
  theirtextbox.Visible := false;
  sendbutton.Visible := false;
  correctingLetter.Visible := false;
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
  
  correctingLetter.Top := 450;
  correctingLetter.Left := 600;
  correctingLetter.Parent := mainform;
  
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
  кнопка1.Click += Ports;
  кнопка2.Click += Ports;
  mainform.Closed += StopProgram;
  theirtextbox.MouseClick += tryToClick;
  System.Windows.Forms.Application.Run(mainform);
end.