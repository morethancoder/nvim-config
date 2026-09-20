; extends

; author => https://www.reddit.com/r/golang/comments/1iw7ch2/use_treesitter_to_highlight_your_string_literals/
; This injection provides syntax highlighting for variable declaration and arguments by
; using the comment before the target string as the language.
;
; The dot after @injection.language ensures only comment text left to the target string will
; trigger injection.
;
; Example:
;   const foo = /* sql */ "SELECT * FROM table"
;   const foo = /* sql */ `SELECT * FROM table`
;   foo := /* sql */ "SELECT * from table"
;   foo := /* sql */ `SELECT * from table`
;   db.Query(/* sql */ "SELECT * from table")
;   db.Query(/* sql */ `SELECT * from table`)
;   const tmpl = /*gotmpl*/ `{{ if .Foo }}{{.Foo}}{{end}} bar`
;   const js = /*javascript*/ `console.log("foo")`
(
  [
    ; const foo = /* lang */ "..."
    ; const foo = /* lang */ `...`
    (
      const_spec
        (comment) @injection.language .
        value: (expression_list 
          [
            (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
            (raw_string_literal (raw_string_literal_content) @injection.content) 
          ]
        )
    )
    ; foo := /* lang */ "..."
    ; foo := /* lang */ `...`
    (
      short_var_declaration
        (comment) @injection.language .
        right: (expression_list
          [
            (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
            (raw_string_literal (raw_string_literal_content) @injection.content) 
          ]
      )
    )
    ; var foo = /* lang */ "..."
    ; var foo = /* lang */ `...`
    (
      var_spec
        (comment) @injection.language .
        value: (expression_list
          [
            (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
            (raw_string_literal (raw_string_literal_content) @injection.content) 
          ]
      )
    )
    ; fn(/*lang*/ "...")
    ; fn(/*lang*/ `...`)
    (
      argument_list
        (comment) @injection.language .
          [
            (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
            (raw_string_literal (raw_string_literal_content) @injection.content) 
          ]
    )
    ; []byte(/*lang*/ "...")
    ; []byte(/*lang*/ `...`)
    (
      type_conversion_expression
        (comment) @injection.language .
        operand:  [
            (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
            (raw_string_literal (raw_string_literal_content) @injection.content) 
          ]
    )
    ; []Type{ /*lang*/ "..." }
    ; []Type{ /*lang*/ `...` }
    (
      literal_value
      (comment) @injection.language .
      (literal_element
          [
            (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
            (raw_string_literal (raw_string_literal_content) @injection.content) 
          ]
      )
    )
    ; map[Type]Type{ key: /*lang*/ "..." }
    ; map[Type]Type{ key: /*lang*/ `...` }
    (
      keyed_element
      (comment) @injection.language .
      value: (literal_element
          [
            (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
            (raw_string_literal (raw_string_literal_content) @injection.content) 
          ]
      )
    )
  ]
  (#gsub! @injection.language "/%*%s*([%w%p]+)%s*%*/" "%1")
)
