# coding: utf-8
# frozen_string_literal: true
require "../../spec_helper"

class GraphQL::Language::Parser
  def self.parse(prog : String, options = NamedTuple.new)
    new(GraphQL::Language::Lexer.new).parse(prog).as(GraphQL::Language::Document)
  end
end

def clean_string(string)
  string.gsub(/^  /m, "")
        .gsub(/#[^\n]*\n/m, "\n")
        .gsub(/[\n\s]+/m, "\n").strip
end

describe GraphQL::Language::Generation do
  query_string = %{
    query getStuff($someVar: Int = 1, $anotherVar: [String!], $skipNested: Boolean! = false) @skip(if: false) {
      myField: someField(someArg: $someVar, ok: 1.4) @skip(if: $anotherVar) @thing(or: "Whatever")
      anotherField(someArg: [1, 2, 3]) {
        nestedField
        ...moreNestedFields @skip(if: $skipNested)
      }
      ... on OtherType @include(unless: false) {
        field(arg: [{key: "value", anotherKey: 0.9, anotherAnotherKey: WHATEVER}])
        anotherField
      }
      ... {
        id
      }
    }

    fragment moreNestedFields on NestedType @or(something: "ok") {
      anotherNestedField
    }
  }

  document = GraphQL::Language::Parser.parse(query_string)
  describe ".generate" do
    it "should work" do
      document = GraphQL::Language::Parser.parse query_string
      document.to_query_string.gsub(/\s+/, " ").strip.should eq query_string.gsub(/\s+/, " ").strip
    end

    it "generates query string" do
      document.to_query_string.gsub(/\s+/, " ").strip.should eq query_string.gsub(/\s+/, " ").strip
    end

    context "inputs" do
      query_string = <<-QUERY
        query {
          field(null_value: null, null_in_array: [1, null, 3], int: 3, float: 4.7e-24, bool: false, string: "☀︎🏆\\n escaped \\" unicode ¶ /", enum: ENUM_NAME, array: [7, 8, 9], object: {a: [1, 2, 3], b: {c: "4"}}, unicode_bom: "\xef\xbb\xbfquery")
        }
      QUERY
      document = GraphQL::Language::Parser.parse(query_string)

      it "generate" do
        document.to_query_string.gsub(/(\s+|\n)/, " ").should eq query_string.gsub(/(\s+|\n)/, " ").strip
      end
    end

    describe "schema" do
      describe "schema with convention names for root types" do
        query_string = <<-SCHEMA
          schema {
            query: Query
            mutation: Mutation
            subscription: Subscription
          }
        SCHEMA

        document = GraphQL::Language::Parser.parse(query_string)

        it "omits schema definition" do
          document.to_query_string.should_not eq /schema/
        end
      end

      context "schema with custom query root name" do
        query_string = <<-SCHEMA
          schema {
            query: MyQuery
            mutation: Mutation
            subscription: Subscription
          }
        SCHEMA

        document = GraphQL::Language::Parser.parse(query_string)

        it "includes schema definition" do
          document.to_query_string.should eq query_string.gsub(/^  /m, "").strip
        end
      end

      describe "schema with custom mutation root name" do
        query_string = <<-SCHEMA
          schema {
            query: Query
            mutation: MyMutation
            subscription: Subscription
          }
        SCHEMA

        document = GraphQL::Language::Parser.parse(query_string)

        it "includes schema definition" do
          document.to_query_string.should eq query_string.gsub(/^  /m, "").strip
        end
      end

      context "schema with custom subscription root name" do
        query_string = <<-SCHEMA
          schema {
            query: Query
            mutation: Mutation
            subscription: MySubscription
          }
        SCHEMA

        document = GraphQL::Language::Parser.parse(query_string)

        it "includes schema definition" do
          document.to_query_string.should eq query_string.gsub(/^  /m, "").strip
        end
      end

      describe "full featured schema" do
        # From: https://github.com/graphql/graphql-js/blob/b883320afb0fae3318afe9da0b0c0da9eed4e6f7/src/language/__tests__/schema-kitchen-sink.graphql
        query_string = <<-SCHEMA
          """This is a description of the schema as a whole."""
          schema {
            query: QueryType
            mutation: MutationType
          }
          
          """
          This is a description
          of the `Foo` type.
          """
          type Foo implements Bar & Baz & Two {
            "Description of the `one` field."
            one: Type
            """
            This is a description of the `two` field.
            """
            two(
              """
              This is a description of the `argument` argument.
              """
              argument: InputType!
            ): Type
            """This is a description of the `three` field."""
            three(argument: InputType, other: String): Int
            four(argument: String = "string"): String
            five(argument: [String] = ["string", "string"]): String
            six(argument: InputType = {key: "value"}): Type
            seven(argument: Int = null): Type
          }
          
          type AnnotatedObject @onObject(arg: "value") {
            annotatedField(arg: Type = "default" @onArgumentDefinition): Type @onField
          }
          
          type UndefinedType
          
          extend type Foo {
            seven(argument: [String]): Type
          }
          
          extend type Foo @onType
          
          interface Bar {
            one: Type
            four(argument: String = "string"): String
          }
          
          interface AnnotatedInterface @onInterface {
            annotatedField(arg: Type @onArgumentDefinition): Type @onField
          }
          
          interface UndefinedInterface
          
          extend interface Bar implements Two {
            two(argument: InputType!): Type
          }
          
          extend interface Bar @onInterface
          
          interface Baz implements Bar & Two {
            one: Type
            two(argument: InputType!): Type
            four(argument: String = "string"): String
          }
          
          union Feed =
            | Story
            | Article
            | Advert
          
          union AnnotatedUnion @onUnion = A | B
          
          union AnnotatedUnionTwo @onUnion = | A | B
          
          union UndefinedUnion
          
          extend union Feed = Photo | Video
          
          extend union Feed @onUnion
          
          scalar CustomScalar
          
          scalar AnnotatedScalar @onScalar
          
          extend scalar CustomScalar @onScalar
          
          enum Site {
            """
            This is a description of the `DESKTOP` value
            """
            DESKTOP
          
            """This is a description of the `MOBILE` value"""
            MOBILE
          
            "This is a description of the `WEB` value"
            WEB
          }
          
          enum AnnotatedEnum @onEnum {
            ANNOTATED_VALUE @onEnumValue
            OTHER_VALUE
          }
          
          enum UndefinedEnum
          
          extend enum Site {
            VR
          }
          
          extend enum Site @onEnum
          
          input InputType {
            key: String!
            answer: Int = 42
          }
          
          input AnnotatedInput @onInputObject {
            annotatedField: Type @onInputFieldDefinition
          }
          
          input UndefinedInput
          
          extend input InputType {
            other: Float = 1.23e4 @onInputFieldDefinition
          }
          
          extend input InputType @onInputObject
          
          """
          This is a description of the `@skip` directive
          """
          directive @skip(
            """This is a description of the `if` argument"""
            if: Boolean! @onArgumentDefinition
          ) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT
          directive @include(if: Boolean!)
            on FIELD
            | FRAGMENT_SPREAD
            | INLINE_FRAGMENT
          directive @include2(if: Boolean!) on
            | FIELD
            | FRAGMENT_SPREAD
            | INLINE_FRAGMENT
          directive @myRepeatableDir(name: String!) repeatable on
            | OBJECT
            | INTERFACE
          extend schema @onSchema
          extend schema @onSchema {
            subscription: SubscriptionType
          }
        SCHEMA

        document = GraphQL::Language::Parser.parse(query_string)

        it "generate" do
          clean_string(
            document.to_query_string
          ).should eq clean_string(
            query_string
          )
        end

        it "generate argument default to null" do
          query_string = <<-SCHEMA
            type Foo {
              one(argument: String = null): Type
              two(argument: Color = Red): Type
            }
          SCHEMA

          expected = <<-SCHEMA
            type Foo {
              one(argument: String): Type
              two(argument: Color = Red): Type
            }
          SCHEMA

          document = GraphQL::Language::Parser.parse(query_string)

          clean_string(
            document.to_query_string
          ).should eq clean_string(
            expected
          )
        end

        it "doesn't mutate the document" do
          document.to_query_string.should eq document.to_query_string
        end
      end
    end
  end
end
