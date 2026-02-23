import Testing
@testable import JARVIS

@Suite("SchemaValidator Tests")
struct SchemaValidatorTests {

    // Helper to build a simple object schema
    private func schema(
        properties: [String: JSONValue] = [:],
        required: [String] = []
    ) -> JSONValue {
        var obj: [String: JSONValue] = ["type": .string("object")]
        if !properties.isEmpty {
            obj["properties"] = .object(properties)
        }
        if !required.isEmpty {
            obj["required"] = .array(required.map { .string($0) })
        }
        return .object(obj)
    }

    private func stringProp() -> JSONValue {
        .object(["type": .string("string")])
    }

    private func numberProp() -> JSONValue {
        .object(["type": .string("number")])
    }

    private func integerProp() -> JSONValue {
        .object(["type": .string("integer")])
    }

    private func boolProp() -> JSONValue {
        .object(["type": .string("boolean")])
    }

    // MARK: - Tests

    @Test func validInputWithAllRequiredFieldsPasses() throws {
        let s = schema(
            properties: ["name": stringProp()],
            required: ["name"]
        )
        try SchemaValidator.validate(input: ["name": .string("JARVIS")], against: s)
    }

    @Test func missingRequiredFieldThrows() {
        let s = schema(
            properties: ["name": stringProp()],
            required: ["name"]
        )
        #expect(throws: SchemaValidationError.missingRequired(field: "name")) {
            try SchemaValidator.validate(input: [:], against: s)
        }
    }

    @Test func stringFieldGivenNumberThrowsTypeMismatch() {
        let s = schema(properties: ["name": stringProp()])
        #expect(throws: SchemaValidationError.typeMismatch(field: "name", expected: "string", got: "number")) {
            try SchemaValidator.validate(input: ["name": .number(42)], against: s)
        }
    }

    @Test func numberFieldGivenStringThrowsTypeMismatch() {
        let s = schema(properties: ["count": numberProp()])
        #expect(throws: SchemaValidationError.typeMismatch(field: "count", expected: "number", got: "string")) {
            try SchemaValidator.validate(input: ["count": .string("hello")], against: s)
        }
    }

    @Test func boolFieldGivenStringThrowsTypeMismatch() {
        let s = schema(properties: ["flag": boolProp()])
        #expect(throws: SchemaValidationError.typeMismatch(field: "flag", expected: "boolean", got: "string")) {
            try SchemaValidator.validate(input: ["flag": .string("true")], against: s)
        }
    }

    @Test func integerFieldGivenWholeNumberPasses() throws {
        let s = schema(properties: ["count": integerProp()])
        try SchemaValidator.validate(input: ["count": .number(3)], against: s)
    }

    @Test func integerFieldGivenFractionalNumberThrowsTypeMismatch() {
        let s = schema(properties: ["count": integerProp()])
        #expect(throws: SchemaValidationError.typeMismatch(field: "count", expected: "integer", got: "number")) {
            try SchemaValidator.validate(input: ["count": .number(3.5)], against: s)
        }
    }

    @Test func invalidEnumValueThrows() {
        let s = schema(properties: [
            "color": .object([
                "type": .string("string"),
                "enum": .array([.string("red"), .string("green"), .string("blue")])
            ])
        ])
        #expect(throws: SchemaValidationError.invalidEnumValue(
            field: "color",
            value: "purple",
            allowed: ["red", "green", "blue"]
        )) {
            try SchemaValidator.validate(input: ["color": .string("purple")], against: s)
        }
    }

    @Test func validEnumValuePasses() throws {
        let s = schema(properties: [
            "color": .object([
                "type": .string("string"),
                "enum": .array([.string("red"), .string("green"), .string("blue")])
            ])
        ])
        try SchemaValidator.validate(input: ["color": .string("red")], against: s)
    }

    @Test func emptySchemaWithEmptyInputPasses() throws {
        let s = schema()
        try SchemaValidator.validate(input: [:], against: s)
    }

    @Test func extraFieldsInInputAreAllowed() throws {
        let s = schema(properties: ["name": stringProp()])
        // Input has an extra "age" field not in properties — should pass
        try SchemaValidator.validate(
            input: ["name": .string("JARVIS"), "age": .number(1)],
            against: s
        )
    }

    @Test func invalidSchemaNonObjectThrowsInvalidSchema() {
        let s = JSONValue.string("not an object")
        #expect(throws: SchemaValidationError.invalidSchema("Schema must be a JSON object")) {
            try SchemaValidator.validate(input: [:], against: s)
        }
    }

    @Test func invalidSchemaTypeNotObjectThrowsInvalidSchema() {
        let s = JSONValue.object(["type": .string("array")])
        #expect(throws: SchemaValidationError.invalidSchema("Schema top-level type must be \"object\"")) {
            try SchemaValidator.validate(input: [:], against: s)
        }
    }
}
