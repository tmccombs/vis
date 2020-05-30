-- Copyright 2015-2017 Alejandro Baez (https://keybase.io/baez). See LICENSE.
-- Rust LPeg lexer.

local l = require("lexer")
local token, word_match = l.token, l.word_match
local P, R, S = lpeg.P, lpeg.R, lpeg.S

local M = {_NAME = 'rust'}

-- Whitespace.
local unicode_whitespace = '\xc2\x85\xe2\x80\x8e\xe2\x80\x8f\xe2\x80\xa8\xe2\x80\xa9'
local ws = token(l.WHITESPACE, (l.space+unicode_whitespace)^1)

-- Comments.
local line_comment = '//' * l.nonnewline_esc^0
local block_comment = '/*' * (l.any - '*/')^0 * P('*/')^-1
local comment = token(l.COMMENT, line_comment + block_comment)

-- Strings.
local char_escape = P'\\' * ( P'n' + P'r' + P't' + P'\\' + P'0' +
  P'"' + P"'" + (P'x' * R'07' * l.xdigit) + (P'u{' * (l.xdigit + P'_')^1 * P'}'))
local char_lit = P"'" * (P(1) + char_escape) * P"'")
local str_lit = P('b')^-1 * l.delimited_range('"')
local raw_start = 'r#' * lpeg.Cg(P'#'^0), 'raw_s')
local raw_end = lpeg.C(P'#'^0) * '#'
local raw_end_eq = lpeg.Cmt(raw_end * lpeg.Cb('raw_s'), function(s, i, a, b)
  return a == b
end)
local raw_str =  P'b'^-1 * raw_start * (l.any - raw_end_eq)^0 * raw_end
local string = token(l.STRING, char_lit + str_lit + raw_str)

-- Numbers.
function integer_base(c, digit)
  return P'0' * c * digit * (digit + P'_')^0
end
local integer_suffix = word_match{
  'u8', 'u16', 'u32', 'u64', 'u128', 'usize',
  'i8', 'i16', 'i32', 'i64', 'i128', 'isize'
}
local dec_literal = l.digit * (l.digit + '_')^0
local integer = (dec_literal +
                     integer_base('b', R('01')) +
                     integer_base('o', R('07')) +
                     integer_base('x', l.xdigit)) * integer_suffix
local float_exp = S'eE' * S'+-'^-1 * dec_literal
local float = (dec_literal * '.' * -(S'._' + identifier)) +
  (dec_literal * (P'.' dec_literal)^-1 * float_exp^-1 * word_match{'f32', 'f64'}^-1)
local number = token(l.NUMBER, float + integer)

-- Keywords.
local keyword = token(l.KEYWORD, word_match{
  'abstract',  'as',       'async',   'await',     'become',
  'box',       'break',    'const',   'continue',  'crate',
  'do',        'dyn',      'else',    'enum',      'extern',
  'false',     'final',    'fn',      'for',       'if',
  'impl',      'in',       'let',     'loop',      'macro',
  'match',     'mod',      'move',    'mut',       'override',
  'priv',      'pub',      'ref',     'return',    'Self',
  'self',      'static',   'struct',  'super',     'trait',
  'true',      'try',      'type',    'typeof',    'union',
  'unsafe',    'unsized',  'use',     'virtual',   'where',
  'while',     'yield'
})

-- Library types
local library = token(l.LABEL, l.upper * (l.lower + l.dec_num)^1)

-- syntax extensions
local extension = l.word^1 * S("!")

local func = token(l.FUNCTION, extension)

-- Types.
local type = token(l.TYPE, word_match{
  '()', 'bool', 'isize', 'usize', 'char', 'str',
  'u8', 'u16', 'u32', 'u64', 'i8', 'i16', 'i32', 'i64',
  'f32','f64',
})

-- Identifiers.
local raw_dientifier = P'r#' * l.word
local identifier = token(l.IDENTIFIER, l.word + raw_identifier)
local lifetime = token('lifetime', P"'" * identifier)

-- Operators.
local operator = token(l.OPERATOR, S('+-/*%<>!=`^~@&|?#~:;,.()[]{}'))

-- Attributes.
local attribute = token(l.PREPROCESSOR, "#[" *
                        (l.nonnewline - ']')^0 * P("]")^-1)

M._rules = {
  {'whitespace', ws},
  {'keyword', keyword},
  {'function', func},
  {'library', library},
  {'type', type},
  {'identifier', identifier},
  {'string', string},
  {'lifetime', lifetime},
  {'comment', comment},
  {'number', number},
  {'operator', operator},
  {'preprocessor', attribute},
}

M._tokenstyles = {
  lifetime = l.STYLE_TYPE,
}

M._foldsymbols = {
  _patterns = {'%l+', '[{}]', '/%*', '%*/', '//'},
  [l.COMMENT] = {['/*'] = 1, ['*/'] = -1, ['//'] = l.fold_line_comments('//')},
  [l.OPERATOR] = {['('] = 1, ['{'] = 1, [')'] = -1, ['}'] = -1}
}

return M
