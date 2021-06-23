import 'dart:ffi';
import 'dart:typed_data';
import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';

class SerialPort {
  /// [portName] like COM3
  final String portName;

  /// just a native string
  final LPWSTR _portNameUtf16;

  /// [dcb] is win32 [DCB] struct
  final dcb = calloc<DCB>();

  /// win32 [COMMTIMEOUTS] struct
  final commTimeouts = calloc<COMMTIMEOUTS>();

  /// file handle
  /// [handler] will be [INVALID_HANDLE_VALUE] if failed
  int? handler;

  Pointer<DWORD> _bytesRead = calloc<DWORD>();

  Pointer<OVERLAPPED> _over = calloc<OVERLAPPED>();

  /// [_keyPath] is registry path which will be oepned
  static final _keyPath = TEXT("HARDWARE\\DEVICEMAP\\SERIALCOMM");

  /// [isOpened] is true when port was opened, [CreateFile] function will open a port.
  bool _isOpened = false;

  bool get isOpened => _isOpened;

  static final Map<String, SerialPort> _cache = <String, SerialPort>{};

  /// reusable instance using [factory]
  factory SerialPort(
    String portName, {
    // ignore: non_constant_identifier_names
    int BaudRate = CBR_115200,
    // ignore: non_constant_identifier_names
    int Parity = NOPARITY,
    // ignore: non_constant_identifier_names
    int StopBits = ONESTOPBIT,
    // ignore: non_constant_identifier_names
    int ByteSize = 8,
    // ignore: non_constant_identifier_names
    int ReadIntervalTimeout = 10,
    // ignore: non_constant_identifier_names
    int ReadTotalTimeoutConstant = 1,
    // ignore: non_constant_identifier_names
    int ReadTotalTimeoutMultiplier = 0,

    /// if you want open port when create instance, set [openNow] true
    bool openNow = true,
  }) {
    return _cache.putIfAbsent(
        portName,
        () => SerialPort._internal(
              portName,
              TEXT(portName),
              BaudRate: BaudRate,
              Parity: Parity,
              StopBits: StopBits,
              ByteSize: ByteSize,
              ReadIntervalTimeout: ReadIntervalTimeout,
              ReadTotalTimeoutConstant: ReadTotalTimeoutConstant,
              ReadTotalTimeoutMultiplier: ReadTotalTimeoutMultiplier,
              openNow: openNow,
            ));
  }

  SerialPort._internal(
    this.portName,
    this._portNameUtf16, {
    // ignore: non_constant_identifier_names
    required int BaudRate,
    // ignore: non_constant_identifier_names
    required int Parity,
    // ignore: non_constant_identifier_names
    required int StopBits,
    // ignore: non_constant_identifier_names
    required int ByteSize,
    // ignore: non_constant_identifier_names
    required int ReadIntervalTimeout,
    // ignore: non_constant_identifier_names
    required int ReadTotalTimeoutConstant,
    // ignore: non_constant_identifier_names
    required int ReadTotalTimeoutMultiplier,
    required bool openNow,
  }) {
    dcb
      ..ref.BaudRate = BaudRate
      ..ref.Parity = Parity
      ..ref.StopBits = StopBits
      ..ref.ByteSize = ByteSize;
    commTimeouts
      ..ref.ReadIntervalTimeout = 10
      ..ref.ReadTotalTimeoutConstant = 1
      ..ref.ReadTotalTimeoutMultiplier = 0;
    if (openNow) {
      open();
    }
  }

  /// [open] can be called when handler is null or handler is closed
  void open() {
    if (_isOpened == false) {
      handler = CreateFile(_portNameUtf16, GENERIC_READ | GENERIC_WRITE, 0,
          nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);

      if (handler == INVALID_HANDLE_VALUE) {
        final lastError = GetLastError();
        if (lastError == ERROR_FILE_NOT_FOUND) {
          throw Exception(_portNameUtf16.toDartString() + "is not available");
        } else {
          throw Exception('Last error is $lastError');
        }
      }

      _setCommState();

      _setCommTimeouts();

      _isOpened = true;
    } else {
      throw Exception('Port is opened');
    }
  }

  /// if you want open a port with some extra settings, use [openWithSettings]
  void openWithSettings({
    // ignore: non_constant_identifier_names
    int BaudRate = CBR_115200,
    // ignore: non_constant_identifier_names
    int Parity = NOPARITY,
    // ignore: non_constant_identifier_names
    int StopBits = ONESTOPBIT,
    // ignore: non_constant_identifier_names
    int ByteSize = 8,
    // ignore: non_constant_identifier_names
    int ReadIntervalTimeout = 10,
    // ignore: non_constant_identifier_names
    int ReadTotalTimeoutConstant = 1,
    // ignore: non_constant_identifier_names
    int ReadTotalTimeoutMultiplier = 0,
  }) {
    dcb
      ..ref.BaudRate = BaudRate
      ..ref.Parity = Parity
      ..ref.StopBits = StopBits
      ..ref.ByteSize = ByteSize;
    commTimeouts
      ..ref.ReadIntervalTimeout = 10
      ..ref.ReadTotalTimeoutConstant = 1
      ..ref.ReadTotalTimeoutMultiplier = 0;
    open();
  }

  /// When [dcb] struct is changed, you must call [_setCommState] to update settings.
  void _setCommState() {
    if (SetCommState(handler!, dcb) == FALSE) {
      throw Exception('SetCommState error');
    } else {
      PurgeComm(handler!, PURGE_RXCLEAR | PURGE_TXCLEAR);
    }
  }

  /// When [commTimeouts] struct is changed, you must call [_setCommTimeouts] to update settings.
  void _setCommTimeouts() {
    if (SetCommTimeouts(handler!, commTimeouts) == FALSE) {
      throw Exception('SetCommTimeouts error');
    }
  }

  // set serial port [BaudRate]
  /// using standard win32 Value like [CBR_115200]
  // ignore: non_constant_identifier_names
  set BaudRate(int rate) {
    dcb.ref.BaudRate = rate;
    _setCommState();
  }

  /// data byteSize
  // ignore: non_constant_identifier_names
  set ByteSize(int size) {
    dcb.ref.ByteSize = size;
    _setCommState();
  }

  /// 1 stop bit is [ONESTOPBIT], value is 0
  /// more docs in https://docs.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-dcb
  // ignore: non_constant_identifier_names
  set StopBits(int stopBits) {
    dcb.ref.StopBits = stopBits;
    _setCommState();
  }

  /// You can use [NOPARITY], [ODDPARITY] and so on like win32
  // ignore: non_constant_identifier_names
  set Parity(int parity) {
    dcb.ref.Parity = parity;
    _setCommState();
  }

  /// [ReadIntervalTimeout]
  ///
  /// The maximum time allowed to elapse before the arrival of the next byte on the communications line,
  /// in milliseconds. If the interval between the arrival of any two bytes exceeds this amount,
  /// the ReadFile operation is completed and any buffered data is returned.
  /// A value of zero indicates that interval time-outs are not used.
  ///
  // ignore: non_constant_identifier_names
  set ReadIntervalTimeout(int readIntervalTimeout) {
    commTimeouts.ref.ReadTotalTimeoutConstant = readIntervalTimeout;
    _setCommTimeouts();
  }

  /// [ReadTotalTimeoutMultiplier]
  ///
  /// The multiplier used to calculate the total time-out period for read operations, in milliseconds.
  /// For each read operation, this value is multiplied by the requested number of bytes to be read
  ///
  // ignore: non_constant_identifier_names
  set ReadTotalTimeoutMultiplier(int readTotalTimeoutMultiplier) {
    commTimeouts.ref.ReadTotalTimeoutMultiplier = readTotalTimeoutMultiplier;
    _setCommTimeouts();
  }

  /// A constant used to calculate the total time-out period for read operations, in milliseconds.
  /// For each read operation, this value is added to the product of the [ReadTotalTimeoutMultiplier]
  /// member and the requested number of bytes.
  ///
  /// A value of zero for both the [ReadTotalTimeoutMultiplier] and [ReadTotalTimeoutConstant] members
  /// indicates that total time-outs are not used for read operations.
  ///
  // ignore: non_constant_identifier_names
  set ReadTotalTimeoutConstant(int readTotalTimeoutConstant) {
    commTimeouts.ref.ReadTotalTimeoutConstant = readTotalTimeoutConstant;
    _setCommTimeouts();
  }

  /// [WriteTotalTimeoutMultiplier]
  ///
  /// The multiplier used to calculate the total time-out period for write operations, in milliseconds.
  /// For each write operation, this value is multiplied by the number of bytes to be written.
  ///
  // ignore: non_constant_identifier_names
  set WriteTotalTimeoutMultiplier(int writeTotalTimeoutMultiplier) {
    commTimeouts.ref.WriteTotalTimeoutMultiplier = writeTotalTimeoutMultiplier;
    _setCommTimeouts();
  }

  /// [WriteTotalTimeoutConstant]
  ///
  /// A constant used to calculate the total time-out period for write operations, in milliseconds.
  /// For each write operation, this value is added to the product of the WriteTotalTimeoutMultiplier
  /// member and the number of bytes to be written.
  ///
  /// A value of zero for both the WriteTotalTimeoutMultiplier and WriteTotalTimeoutConstant
  /// members indicates that total time-outs are not used for write operations.
  ///
  // ignore: non_constant_identifier_names
  set WriteTotalTimeoutConstant(int writeTotalTimeoutConstant) {
    commTimeouts.ref.WriteTotalTimeoutConstant = writeTotalTimeoutConstant;
    _setCommTimeouts();
  }

  /// [readBytes] is an [async] function
  Future<Uint8List> readBytes(int bytesSize) async {
    final lpBuffer = calloc<Uint16>(bytesSize);
    ReadFile(handler!, lpBuffer, bytesSize, _bytesRead, _over);

    /// Uint16 need to be casted for real Uint8 data
    return lpBuffer.cast<Uint8>().asTypedList(_bytesRead.value);
  }

  /// [writeBytesFromString] will convert String to ANSI Code corresponding to char
  /// Serial devices can receive ANSI code
  /// if you write "hello" in String, device will get "hello\0" with "\0" automatically.
  bool writeBytesFromString(String buffer) {
    final lpBuffer = buffer.toANSI();
    final lpNumberOfBytesWritten = calloc<DWORD>();
    try {
      if (WriteFile(handler!, lpBuffer, lpBuffer.length + 1,
              lpNumberOfBytesWritten, nullptr) !=
          TRUE) {
        return false;
      }
      return true;
    } finally {
      free(lpBuffer);
      free(lpNumberOfBytesWritten);
    }
  }

  /// [writeBytesFromUint8List] will write Uint8List directly, please ensure the last
  /// of list is 0 terminator if you want to convert it to char.
  bool writeBytesFromUint8List(Uint8List uint8list) {
    final lpBuffer = uint8list.allocatePointer();
    final lpNumberOfBytesWritten = calloc<DWORD>();
    try {
      if (WriteFile(handler!, lpBuffer, uint8list.length,
              lpNumberOfBytesWritten, nullptr) !=
          TRUE) {
        return false;
      }
      return true;
    } finally {
      free(lpBuffer);
      free(lpNumberOfBytesWritten);
    }
  }

  /// [_getRegistryKeyValue] will open RegistryKey in Serial Path.
  static int _getRegistryKeyValue() {
    final hKeyPtr = calloc<IntPtr>();
    try {
      if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, _keyPath, 0, KEY_READ, hKeyPtr) !=
          ERROR_SUCCESS) {
        RegCloseKey(hKeyPtr.value);
        throw Exception("can't open Register");
      }
      return hKeyPtr.value;
    } finally {
      free(hKeyPtr);
    }
  }

  static String? _enumerateKey(int hKey, int dwIndex) {
    /// [lpValueName]
    /// A pointer to a buffer that receives the name of the value as a null-terminated string.
    /// This buffer must be large enough to include the terminating null character.
    final lpValueName = wsalloc(MAX_PATH);

    /// [lpcchValueName]
    /// A pointer to a variable that specifies the size of the buffer pointed to by the lpValueName parameter
    final lpcchValueName = calloc<DWORD>();
    lpcchValueName.value = MAX_PATH;

    /// A pointer to a variable that receives a code indicating the type of data stored in the specified value.
    final lpType = calloc<DWORD>();

    /// A pointer to a buffer that receives the data for the value entry.
    /// This parameter can be NULL if the data is not required.
    final lpData = calloc<BYTE>(MAX_PATH);

    /// [lpcbData]
    /// A pointer to a variable that specifies the size of the buffer pointed to by the lpData parameter, in bytes.
    /// When the function returns, the variable receives the number of bytes stored in the buffer.
    final lpcbData = calloc<DWORD>();
    lpcbData.value = MAX_PATH;

    try {
      final status = RegEnumValue(hKey, dwIndex, lpValueName, lpcchValueName,
          nullptr, lpType, lpData, lpcbData);

      switch (status) {
        case ERROR_SUCCESS:
          return lpData.cast<Utf16>().toDartString();
        case ERROR_MORE_DATA:
          throw Exception("ERROR_MORE_DATA");
        case ERROR_NO_MORE_ITEMS:
          return null;
        default:
          throw Exception("Unknown error!");
      }
    } finally {
      /// free all pointer
      free(lpValueName);
      free(lpcchValueName);
      free(lpType);
      free(lpData);
      free(lpcbData);
    }
  }

  /// read Registry in Windows to get ports
  /// [getAvailablePorts] can be called using SerialPort.getAvailablePorts()
  static List<String> getAvailablePorts() {
    /// availablePorts String list
    List<String> portsList = [];

    final hKey = _getRegistryKeyValue();

    /// The index of the value to be retrieved.
    /// This parameter should be zero for the first call to the RegEnumValue function and then be incremented for subsequent calls.
    int dwIndex = 0;

    String? item;
    item = _enumerateKey(hKey, dwIndex);
    if (item == null) {
      portsList.add('');
    }

    while (item != null) {
      portsList.add(item);
      dwIndex++;
      item = _enumerateKey(hKey, dwIndex);
    }

    RegCloseKey(hKey);

    return portsList;
  }

  /// [close] port which was opened
  void close() {
    CloseHandle(handler!);
    _isOpened = false;
  }
}
