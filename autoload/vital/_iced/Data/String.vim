" ___vital___
" NOTE: lines between '" ___vital___' is generated by :Vitalize.
" Do not modify the code nor insert new lines before '" ___vital___'
function! s:_SID() abort
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze__SID$')
endfunction
execute join(['function! vital#_iced#Data#String#import() abort', printf("return map({'starts_with': '', 'split3': '', 'replace_first': '', 'chop': '', 'unescape': '', 'split_posix_text': '', 'replace': '', 'scan': '', 'strwidthpart': '', 'common_head': '', 'reverse': '', 'escape_pattern': '', 'trim_end': '', '_vital_depends': '', 'wrap': '', 'join_posix_lines': '', 'contains_multibyte': '', 'truncate_skipping': '', 'split_leftright': '', 'ends_with': '', 'nsplit': '', 'strwidthpart_reverse': '', 'unescape_pattern': '', 'levenshtein_distance': '', 'trim_start': '', 'justify_equal_spacing': '', 'nr2hex': '', 'iconv': '', 'pad_left': '', 'nr2enc_char': '', 'lines': '', 'repair_posix_text': '', 'nr2byte': '', 'trim': '', 'diffidx': '', 'truncate': '', 'split_by_displaywidth': '', '_vital_created': '', 'padding_by_displaywidth': '', 'hash': '', 'chomp': '', 'pad_between_letters': '', 'dstring': '', 'pad_both_sides': '', 'substitute_last': '', 'pad_right': '', 'remove_ansi_sequences': '', '_vital_loaded': ''}, \"vital#_iced#function('<SNR>%s_' . v:key)\")", s:_SID()), 'endfunction'], "\n")
delfunction s:_SID
" ___vital___
" Utilities for string.

let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V) abort
  let s:V = a:V
  let s:L = s:V.import('Data.List')
endfunction

function! s:_vital_depends() abort
  return ['Data.List']
endfunction

function! s:_vital_created(module) abort
  " Expose script-local funcref
  let a:module.strchars = function('strchars')
  let a:module.wcswidth = function('strwidth')
endfunction

" Substitute a:from => a:to by string.
" To substitute by pattern, use substitute() instead.
function! s:replace(str, from, to) abort
  return s:_replace(a:str, a:from, a:to, 'g')
endfunction

" Substitute a:from => a:to only once.
" cf. s:replace()
function! s:replace_first(str, from, to) abort
  return s:_replace(a:str, a:from, a:to, '')
endfunction

" implement of replace() and replace_first()
function! s:_replace(str, from, to, flags) abort
  return substitute(a:str, '\V'.escape(a:from, '\'), escape(a:to, '\'), a:flags)
endfunction

function! s:scan(str, pattern) abort
  let list = []
  call substitute(a:str, a:pattern, '\=add(list, submatch(0)) == [] ? "" : ""', 'g')
  return list
endfunction

function! s:reverse(str) abort
  return join(reverse(split(a:str, '.\zs')), '')
endfunction

function! s:starts_with(str, prefix) abort
  return stridx(a:str, a:prefix) == 0
endfunction

function! s:ends_with(str, suffix) abort
  let idx = strridx(a:str, a:suffix)
  return 0 <= idx && idx + len(a:suffix) == len(a:str)
endfunction

function! s:common_head(strs) abort
  if empty(a:strs)
    return ''
  endif
  let len = len(a:strs)
  if len == 1
    return a:strs[0]
  endif
  let strs = len == 2 ? a:strs : sort(copy(a:strs))
  let pat = substitute(strs[0], '.', '\="[" . escape(submatch(0), "^\\") . "]"', 'g')
  return pat ==# '' ? '' : matchstr(strs[-1], '\C^\%[' . pat . ']')
endfunction

" Split to two elements of List. ([left, right])
" e.g.: s:split3('neocomplcache', 'compl') returns ['neo', 'compl', 'cache']
function! s:split_leftright(expr, pattern) abort
  let [left, _, right] = s:split3(a:expr, a:pattern)
  return [left, right]
endfunction

function! s:split3(expr, pattern) abort
  let ERROR = ['', '', '']
  if a:expr ==# '' || a:pattern ==# ''
    return ERROR
  endif
  let begin = match(a:expr, a:pattern)
  if begin is -1
    return ERROR
  endif
  let end   = matchend(a:expr, a:pattern)
  let left  = begin <=# 0 ? '' : a:expr[: begin - 1]
  let right = a:expr[end :]
  return [left, a:expr[begin : end-1], right]
endfunction

" Slices into strings determines the number of substrings.
" e.g.: s:nsplit("neo compl cache", 2, '\s') returns ['neo', 'compl cache']
function! s:nsplit(expr, n, ...) abort
  let pattern = get(a:000, 0, '\s')
  let keepempty = get(a:000, 1, 1)
  let ret = []
  let expr = a:expr
  if a:n <= 1
    return [expr]
  endif

  while len(ret) < a:n - 1
    let pos = match(expr, pattern)
    if pos >= 0 " matched
      let left = pos > 0 ? expr[:pos-1] : ''
      let ml = len(matchstr(expr, pattern))
      let right = expr[pos+ml :]
      if pos > 0 || keepempty
        call add(ret, left)
      endif
      if pos == 0 && ml == 0
        let pos = 1
      endif
      let expr = right
    else " pos == -1 means no more matches
      if expr !~ pattern || keepempty
        call add(ret, expr)
      endif
      let expr = v:none
      break
    endif
  endwhile

  " node count last check
  if len(ret) == a:n - 1 && type(expr) == type('')
    if len(expr) > 0 || keepempty
      call add(ret, expr)
    endif
  endif
  return ret
endfunction

" Returns the bool of contains any multibyte character in s:str
function! s:contains_multibyte(str) abort "{{{
  return strlen(a:str) != strchars(a:str)
endfunction "}}}

" Remove last character from a:str.
" NOTE: This returns proper value
" even if a:str contains multibyte character(s).
function! s:chop(str) abort "{{{
  return substitute(a:str, '.$', '', '')
endfunction "}}}

" Remove last \r,\n,\r\n from a:str.
function! s:chomp(str) abort "{{{
  return substitute(a:str, '\%(\r\n\|[\r\n]\)$', '', '')
endfunction "}}}

" wrap() and its internal functions
" * _split_by_wcswidth_once()
" * _split_by_wcswidth()
" * _concat()
" * wrap()
"
" NOTE _concat() is just a copy of Data.List.concat().
" FIXME don't repeat yourself
function! s:_split_by_wcswidth_once(body, x) abort
  let fst = s:strwidthpart(a:body, a:x)
  let snd = s:strwidthpart_reverse(a:body, strwidth(a:body) - strwidth(fst))
  return [fst, snd]
endfunction

function! s:_split_by_wcswidth(body, x) abort
  let memo = []
  let body = a:body
  while strwidth(body) > a:x
    let [tmp, body] = s:_split_by_wcswidth_once(body, a:x)
    call add(memo, tmp)
  endwhile
  call add(memo, body)
  return memo
endfunction

function! s:trim(str) abort
  return substitute(a:str,'\%#=1^[[:space:]]\+\|[[:space:]]\+$', '', 'g')
endfunction

function! s:trim_start(str) abort
  return substitute(a:str,'\%#=1^[[:space:]]\+', '', '')
endfunction

function! s:trim_end(str) abort
  let i = match(a:str, '\%#=2[[:space:]]*$')
  return i is# 0 ? '' : a:str[: i-1]
endfunction

function! s:wrap(str,...) abort
  let _columns = a:0 > 0 ? a:1 : &columns
  return s:L.concat(
        \ map(split(a:str, '\r\n\|[\r\n]'), 's:_split_by_wcswidth(v:val, _columns - 1)'))
endfunction

function! s:nr2byte(nr) abort
  if a:nr < 0x80
    return nr2char(a:nr)
  elseif a:nr < 0x800
    return nr2char(a:nr/64+192).nr2char(a:nr%64+128)
  else
    return nr2char(a:nr/4096%16+224).nr2char(a:nr/64%64+128).nr2char(a:nr%64+128)
  endif
endfunction

function! s:nr2enc_char(charcode) abort
  if &encoding ==# 'utf-8'
    return nr2char(a:charcode)
  endif
  let char = s:nr2byte(a:charcode)
  if strlen(char) > 1
    let char = strtrans(iconv(char, 'utf-8', &encoding))
  endif
  return char
endfunction

function! s:nr2hex(nr) abort
  let n = a:nr
  let r = ''
  while n
    let r = '0123456789ABCDEF'[n % 16] . r
    let n = n / 16
  endwhile
  return r
endfunction

" If a ==# b, returns -1.
" If a !=# b, returns first index of different character.
function! s:diffidx(a, b) abort
  return a:a ==# a:b ? -1 : strlen(s:common_head([a:a, a:b]))
endfunction

function! s:substitute_last(expr, pat, sub) abort
  return substitute(a:expr, printf('.*\zs%s', a:pat), a:sub, '')
endfunction

function! s:dstring(expr) abort
  let x = substitute(string(a:expr), "^'\\|'$", '', 'g')
  let x = substitute(x, "''", "'", 'g')
  return printf('"%s"', escape(x, '"'))
endfunction

function! s:lines(str) abort
  return split(a:str, '\r\?\n')
endfunction

function! s:_pad_with_char(str, left, right, char) abort
  return repeat(a:char, a:left). a:str. repeat(a:char, a:right)
endfunction

function! s:pad_left(str, width, ...) abort
  let char = get(a:, 1, ' ')
  if strdisplaywidth(char) != 1
    throw "vital: Data.String: Can't use non-half-width characters for padding."
  endif
  let left = max([0, a:width - strdisplaywidth(a:str)])
  return s:_pad_with_char(a:str, left, 0, char)
endfunction

function! s:pad_right(str, width, ...) abort
  let char = get(a:, 1, ' ')
  if strdisplaywidth(char) != 1
    throw "vital: Data.String: Can't use non-half-width characters for padding."
  endif
  let right = max([0, a:width - strdisplaywidth(a:str)])
  return s:_pad_with_char(a:str, 0, right, char)
endfunction

function! s:pad_both_sides(str, width, ...) abort
  let char = get(a:, 1, ' ')
  if strdisplaywidth(char) != 1
    throw "vital: Data.String: Can't use non-half-width characters for padding."
  endif
  let space = max([0, a:width - strdisplaywidth(a:str)])
  let left = space / 2
  let right = space - left
  return s:_pad_with_char(a:str, left, right, char)
endfunction

function! s:pad_between_letters(str, width, ...) abort
  let char = get(a:, 1, ' ')
  if strdisplaywidth(char) != 1
    throw "vital: Data.String: Can't use non-half-width characters for padding."
  endif
  let letters = split(a:str, '\zs')
  let each_width = a:width / len(letters)
  let str = join(map(letters, 's:pad_both_sides(v:val, each_width, char)'), '')
  if a:width - strdisplaywidth(str) > 0
    return char. s:pad_both_sides(str, a:width - 1, char)
  endif
  return str
endfunction

function! s:justify_equal_spacing(str, width, ...) abort
  let char = get(a:, 1, ' ')
  if strdisplaywidth(char) != 1
    throw "vital: Data.String: Can't use non-half-width characters for padding."
  endif
  let letters = split(a:str, '\zs')
  let first_letter = letters[0]
  " {width w/o the first letter} / {length w/o the first letter}
  let each_width = (a:width - strdisplaywidth(first_letter)) / (len(letters) - 1)
  let remainder = (a:width - strdisplaywidth(first_letter)) % (len(letters) - 1)
  return first_letter. join(s:L.concat([
\     map(letters[1:remainder], 's:pad_left(v:val, each_width + 1, char)'),
\     map(letters[remainder + 1:], 's:pad_left(v:val, each_width, char)')
\   ]), '')
endfunction

function! s:levenshtein_distance(str1, str2) abort
  let letters1 = split(a:str1, '\zs')
  let letters2 = split(a:str2, '\zs')
  let length1 = len(letters1)
  let length2 = len(letters2)
  let distances = map(range(1, length1 + 1), 'map(range(1, length2 + 1), ''0'')')

  for i1 in range(0, length1)
    let distances[i1][0] = i1
  endfor
  for i2 in range(0, length2)
    let distances[0][i2] = i2
  endfor

  for i1 in range(1, length1)
    for i2 in range(1, length2)
      let cost = (letters1[i1 - 1] ==# letters2[i2 - 1]) ? 0 : 1

      let distances[i1][i2] = min([
      \ distances[i1 - 1][i2    ] + 1,
      \ distances[i1    ][i2 - 1] + 1,
      \ distances[i1 - 1][i2 - 1] + cost,
      \])
    endfor
  endfor

  return distances[length1][length2]
endfunction

function! s:padding_by_displaywidth(expr, width, float) abort
  let padding_char = ' '
  let n = a:width - strdisplaywidth(a:expr)
  if n <= 0
    let n = 0
  endif
  if a:float < 0
    return a:expr . repeat(padding_char, n)
  elseif 0 < a:float
    return repeat(padding_char, n) . a:expr
  else
    if n % 2 is 0
      return repeat(padding_char, n / 2) . a:expr . repeat(padding_char, n / 2)
    else
      return repeat(padding_char, (n - 1) / 2) . a:expr . repeat(padding_char, (n - 1) / 2) . padding_char
    endif
  endif
endfunction

function! s:split_by_displaywidth(expr, width, float, is_wrap) abort
  if a:width is 0
    return ['']
  endif

  let lines = []

  let cs = split(a:expr, '\zs')
  let cs_index = 0

  let text = ''
  while cs_index < len(cs)
    if cs[cs_index] is# "\n"
      let text = s:padding_by_displaywidth(text, a:width, a:float)
      let lines += [text]
      let text = ''
    else
      let w = strdisplaywidth(text . cs[cs_index])

      if w < a:width
        let text .= cs[cs_index]
      elseif a:width < w
        let text = s:padding_by_displaywidth(text, a:width, a:float)
      else
        let text .= cs[cs_index]
      endif

      if a:width <= w
        let lines += [text]
        let text = ''
        if a:is_wrap
          if a:width < w
            if a:width < strdisplaywidth(cs[cs_index])
              while get(cs, cs_index, "\n") isnot# "\n"
                let cs_index += 1
              endwhile
              continue
            else
              let text = cs[cs_index]
            endif
          endif
        else
          while get(cs, cs_index, "\n") isnot# "\n"
            let cs_index += 1
          endwhile
          continue
        endif
      endif

    endif
    let cs_index += 1
  endwhile

  if !empty(text)
    let lines += [ s:padding_by_displaywidth(text, a:width, a:float) ]
  endif

  return lines
endfunction

function! s:hash(str) abort
  if exists('*sha256')
    return sha256(a:str)
  else
    " This gives up sha256ing but just adds up char with index.
    let sum = 0
    for i in range(len(a:str))
      let sum += char2nr(a:str[i]) * (i + 1)
    endfor

    return printf('%x', sum)
  endif
endfunction

function! s:truncate(str, width) abort
  " Original function is from mattn.
  " http://github.com/mattn/googlereader-vim/tree/master

  if a:str =~# '^[\x00-\x7f]*$'
    return len(a:str) < a:width
          \ ? printf('%-' . a:width . 's', a:str)
          \ : strpart(a:str, 0, a:width)
  endif

  let ret = a:str
  let width = strwidth(a:str)
  if width > a:width
    let ret = s:strwidthpart(ret, a:width)
    let width = strwidth(ret)
  endif

  if width < a:width
    let ret .= repeat(' ', a:width - width)
  endif

  return ret
endfunction

function! s:truncate_skipping(str, max, footer_width, separator) abort
  let width = strwidth(a:str)
  if width <= a:max
    let ret = a:str
  else
    let header_width = a:max - strwidth(a:separator) - a:footer_width
    let ret = s:strwidthpart(a:str, header_width) . a:separator
          \ . s:strwidthpart_reverse(a:str, a:footer_width)
  endif
  return s:truncate(ret, a:max)
endfunction

function! s:strwidthpart(str, width) abort
  let str = tr(a:str, "\t", ' ')
  let vcol = a:width + 2
  return matchstr(str, '.*\%<' . (vcol < 0 ? 0 : vcol) . 'v')
endfunction

function! s:strwidthpart_reverse(str, width) abort
  let str = tr(a:str, "\t", ' ')
  let vcol = strwidth(str) - a:width
  return matchstr(str, '\%>' . (vcol < 0 ? 0 : vcol) . 'v.*')
endfunction

function! s:remove_ansi_sequences(text) abort
  return substitute(a:text, '\e\[\%(\%(\d\+;\)*\d\+\)\?[mK]', '', 'g')
endfunction

function! s:escape_pattern(str) abort
  " escape characters for no-magic
  return escape(a:str, '^$~.*[]\')
endfunction

function! s:unescape_pattern(str) abort
  " unescape characters for no-magic
  return s:unescape(a:str, '^$~.*[]\')
endfunction

function! s:unescape(str, chars) abort
  let chars = map(split(a:chars, '\zs'), 'escape(v:val, ''^$~.*[]\'')')
  return substitute(a:str, '\\\(' . join(chars, '\|') . '\)', '\1', 'g')
endfunction

function! s:iconv(expr, from, to) abort
  if a:from ==# '' || a:to ==# '' || a:from ==? a:to
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return empty(result) ? a:expr : result
endfunction

" NOTE:
" A definition of a TEXT file is "A file that contains characters organized
" into one or more lines."
" A definition of a LINE is "A sequence of zero or more non- <newline>s
" plus a terminating <newline>"
" That's why {stdin} always ends with <newline> ideally. However, there are
" some programs which does not follow the POSIX rule and a Vim's way to join
" List into TEXT; join({text}, "\n"); does not add <newline> to the end of
" the last line.
" That's why add a trailing <newline> if it does not exist.
" REF:
" http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_392
" http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_205
" :help split()
" NOTE:
" it does nothing if the text is a correct POSIX text
function! s:repair_posix_text(text, ...) abort
  let newline = get(a:000, 0, "\n")
  return a:text =~# '\n$' ? a:text : a:text . newline
endfunction

" NOTE:
" A definition of a TEXT file is "A file that contains characters organized
" into one or more lines."
" A definition of a LINE is "A sequence of zero or more non- <newline>s
" plus a terminating <newline>"
" REF:
" http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_392
" http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_205
function! s:join_posix_lines(lines, ...) abort
  let newline = get(a:000, 0, "\n")
  return join(a:lines, newline) . newline
endfunction

" NOTE:
" A definition of a TEXT file is "A file that contains characters organized
" into one or more lines."
" A definition of a LINE is "A sequence of zero or more non- <newline>s
" plus a terminating <newline>"
" TEXT into List; split({text}, '\r\?\n', 1); add an extra empty line at the
" end of List because the end of TEXT ends with <newline> and keepempty=1 is
" specified. (btw. keepempty=0 cannot be used because it will remove
" emptylines in the head and the tail).
" That's why removing a trailing <newline> before proceeding to 'split' is required
" REF:
" http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_392
" http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap03.html#tag_03_205
function! s:split_posix_text(text, ...) abort
  let newline = get(a:000, 0, '\r\?\n')
  let text = substitute(a:text, newline . '$', '', '')
  return split(text, newline, 1)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0:
