#if os(Linux)
    import CMySQLLinux
#else
    import CMySQLMac
#endif

public final class Bind {
    public typealias CBind = MYSQL_BIND

    typealias Char = Int8

    public let cBind: CBind

    public init(cBind: CBind) {
        self.cBind = cBind
    }

    public init() {
        var cBind = CBind()
        cBind.buffer_type = MYSQL_TYPE_NULL

        self.cBind = cBind
    }

    public init(_ field: Field) {
        var cBind = CBind()

        cBind.buffer_type = field.cField.type
        let length = Int(field.cField.length)

        cBind.buffer_length = UInt(length)

        cBind.buffer = UnsafeMutablePointer<Void>(allocatingCapacity: length)
        cBind.length = UnsafeMutablePointer<UInt>(allocatingCapacity: 1)
        cBind.is_null = UnsafeMutablePointer<my_bool>(allocatingCapacity: 1)
        cBind.error = UnsafeMutablePointer<my_bool>(allocatingCapacity: 1)

        self.cBind = cBind
    }

    public convenience init(_ string: String) {
        let bytes = Array(string.utf8)
        let buffer = UnsafeMutablePointer<Char>(allocatingCapacity: bytes.count)
        for (i, byte) in bytes.enumerated() {
            buffer[i] = Char(byte)
        }

        self.init(type: MYSQL_TYPE_STRING, buffer: buffer, bufferLength: bytes.count)
    }

    public convenience init(_ int: Int) {
        let buffer = UnsafeMutablePointer<Int64>(allocatingCapacity: 1)
        buffer.initialize(with: Int64(int))

        self.init(type: MYSQL_TYPE_LONGLONG, buffer: buffer, bufferLength: sizeof(Int64))
    }

    public convenience init(_ int: UInt) {
        let buffer = UnsafeMutablePointer<UInt64>(allocatingCapacity: 1)
        buffer.initialize(with: UInt64(int))

        self.init(type: MYSQL_TYPE_LONGLONG, buffer: buffer, bufferLength: sizeof(UInt64))
    }

    public convenience init(_ int: Double) {
        let buffer = UnsafeMutablePointer<Double>(allocatingCapacity: 1)
        buffer.initialize(with: Double(int))

        self.init(type: MYSQL_TYPE_LONGLONG, buffer: buffer, bufferLength: sizeof(Double))
    }

    public init<T>(type: Database.FieldType, buffer: UnsafeMutablePointer<T>, bufferLength: Int, unsigned: Bool = false) {
        var cBind = CBind()

        cBind.buffer = UnsafeMutablePointer<Void>(buffer)
        cBind.buffer_length = UInt(bufferLength)

        cBind.length = UnsafeMutablePointer<UInt>(allocatingCapacity: 1)
        cBind.length.initialize(with: cBind.buffer_length)


        cBind.buffer_type = type

        if unsigned {
            cBind.is_unsigned = 1
        } else {
            cBind.is_unsigned = 0
        }

        self.cBind = cBind
    }

    public var variant: Field.Variant {
        return cBind.buffer_type
    }

    public var value: Value? {
        guard let buffer = cBind.buffer else {
            return nil
        }

        let value: Value?

        func cast<T>(_ buffer: UnsafeMutablePointer<Void>, _ type: T.Type) -> UnsafeMutablePointer<T> {
            return UnsafeMutablePointer<T>(buffer)
        }

        func unwrap<T>(_ buffer: UnsafeMutablePointer<Void>, _ type: T.Type) -> T {
            return UnsafeMutablePointer<T>(buffer).pointee
        }

        let isNull = cBind.is_null.pointee

        if isNull == 1 {
            value = nil
        } else {
            switch variant {
            case MYSQL_TYPE_STRING,
                 MYSQL_TYPE_VAR_STRING,
                 MYSQL_TYPE_BLOB,
                 MYSQL_TYPE_DECIMAL,
                 MYSQL_TYPE_NEWDECIMAL,
                 MYSQL_TYPE_ENUM,
                 MYSQL_TYPE_SET:
                let string = String(cString: cast(buffer, Bind.Char.self))
                value = .string(string)
            case MYSQL_TYPE_LONG:
                if cBind.is_unsigned == 1 {
                    let uint = unwrap(buffer, UInt32.self)
                    value = .uint(UInt(uint))
                } else {
                    let int = unwrap(buffer, Int32.self)
                    value = .int(Int(int))
                }
            case MYSQL_TYPE_LONGLONG:
                if cBind.is_unsigned == 1 {
                    let uint = unwrap(buffer, UInt64.self)
                    value = .uint(UInt(uint))
                } else {
                    let int = unwrap(buffer, Int64.self)
                    value = .int(Int(int))
                }
            case MYSQL_TYPE_DOUBLE:
                let double = unwrap(buffer, Double.self)
                value = .double(double)
            default:
                value = .null
            }
        }

        return value
    }

    deinit {
        print("GOODBYE BIND!")
        guard cBind.buffer_type != MYSQL_TYPE_NULL else {
            return
        }

        let bufferLength = Int(cBind.buffer_length)

        cBind.buffer.deinitialize()
        cBind.buffer.deallocateCapacity(bufferLength)

        cBind.length.deinitialize()
        cBind.length.deallocateCapacity(1)

        if let pointer = cBind.is_null {
            pointer.deinitialize()
            pointer.deallocateCapacity(1)
        }

        if let pointer = cBind.error {
            pointer.deinitialize()
            pointer.deallocateCapacity(1)
        }
    }
}

extension Value {
    var bind: Bind {
        switch self {
        case .int(let int):
            return Bind(int)
        case .double(let double):
            return Bind(double)
        case .string(let string):
            return Bind(string)
        case .uint(let uint):
            return Bind(uint)
        case .null:
            return Bind()
        }
    }
}
