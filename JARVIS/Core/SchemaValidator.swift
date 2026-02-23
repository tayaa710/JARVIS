// MARK: - SchemaValidationError

enum SchemaValidationError: Error, Equatable {
    case invalidSchema(String)
    case missingRequired(field: String)
    case typeMismatch(field: String, expected: String, got: String)
    case invalidEnumValue(field: String, value: String, allowed: [String])
}

// MARK: - SchemaValidator

enum SchemaValidator {

    /// Validates `input` against a JSON Schema value.
    ///
    /// Supported validations (flat schemas only):
    /// - Top-level schema must be `{ "type": "object" }`
    /// - `required` fields must be present in input
    /// - `properties` type declarations are checked: string, number, integer, boolean, object, array
    /// - `enum` values are enforced when present
    static func validate(input: [String: JSONValue], against schema: JSONValue) throws {
        guard case .object(let schemaObj) = schema else {
            throw SchemaValidationError.invalidSchema("Schema must be a JSON object")
        }

        // Top-level type must be "object"
        if let typeValue = schemaObj["type"] {
            guard case .string(let typeStr) = typeValue, typeStr == "object" else {
                throw SchemaValidationError.invalidSchema("Schema top-level type must be \"object\"")
            }
        } else {
            throw SchemaValidationError.invalidSchema("Schema missing \"type\" field")
        }

        // Extract properties and required arrays
        let properties: [String: JSONValue]
        if let propsValue = schemaObj["properties"], case .object(let propsObj) = propsValue {
            properties = propsObj
        } else {
            properties = [:]
        }

        let required: [String]
        if let reqValue = schemaObj["required"], case .array(let reqArray) = reqValue {
            required = reqArray.compactMap {
                if case .string(let s) = $0 { return s }
                return nil
            }
        } else {
            required = []
        }

        // Check required fields
        for field in required {
            guard input[field] != nil else {
                throw SchemaValidationError.missingRequired(field: field)
            }
        }

        // Validate types and enum values for properties present in input
        for (field, value) in input {
            guard let propSchema = properties[field],
                  case .object(let propObj) = propSchema else {
                // No schema for this field — additionalProperties defaults to allowed
                continue
            }

            // Type check
            if let typeValue = propObj["type"], case .string(let expectedType) = typeValue {
                try checkType(field: field, value: value, expectedType: expectedType)
            }

            // Enum check
            if let enumValue = propObj["enum"], case .array(let enumArray) = enumValue {
                let allowed = enumArray.compactMap { item -> String? in
                    if case .string(let s) = item { return s }
                    return nil
                }
                guard case .string(let strVal) = value, allowed.contains(strVal) else {
                    let got: String
                    if case .string(let s) = value { got = s } else { got = typeName(of: value) }
                    throw SchemaValidationError.invalidEnumValue(
                        field: field,
                        value: got,
                        allowed: allowed
                    )
                }
            }
        }
    }

    // MARK: - Private

    private static func checkType(field: String, value: JSONValue, expectedType: String) throws {
        let matches: Bool
        switch expectedType {
        case "string":
            if case .string = value { matches = true } else { matches = false }
        case "number":
            if case .number = value { matches = true } else { matches = false }
        case "integer":
            if case .number(let d) = value {
                matches = d.truncatingRemainder(dividingBy: 1) == 0
            } else {
                matches = false
            }
        case "boolean":
            if case .bool = value { matches = true } else { matches = false }
        case "object":
            if case .object = value { matches = true } else { matches = false }
        case "array":
            if case .array = value { matches = true } else { matches = false }
        default:
            matches = true // Unknown type — pass through
        }

        if !matches {
            throw SchemaValidationError.typeMismatch(
                field: field,
                expected: expectedType,
                got: typeName(of: value)
            )
        }
    }

    private static func typeName(of value: JSONValue) -> String {
        switch value {
        case .string: return "string"
        case .number: return "number"
        case .bool: return "boolean"
        case .null: return "null"
        case .array: return "array"
        case .object: return "object"
        }
    }
}
