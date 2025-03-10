let s:suite  = themis#suite('iced.nrepl.test')
let s:assert = themis#helper('assert')
let s:scope = themis#helper('scope')
let s:buf = themis#helper('iced_buffer')
let s:ch = themis#helper('iced_channel')
let s:qf = themis#helper('iced_quickfix')
let s:ex = themis#helper('iced_ex_cmd')
let s:holder = themis#helper('iced_holder')
let s:io = themis#helper('iced_io')
let s:sign = themis#helper('iced_sign')
let s:timer = themis#helper('iced_timer')
let s:funcs = s:scope.funcs('autoload/iced/nrepl/test.vim')

let s:temp_foo = tempname()
let s:temp_bar = tempname()

function s:setup(...) abort " {{{
  let opts = get(a:, 1, {})
  call s:ex.mock()
  call s:qf.mock()
  call s:sign.mock()
  call s:timer.mock()

  call s:qf.setlist([])
  call s:holder.clear()
  call s:sign.clear()

  if !get(opts, 'no_temp_files', v:false)
    call writefile(['foo', 'bar', 'baz'], s:temp_foo)
    call writefile(['bar', 'baz', 'foo'], s:temp_bar)
  endif

  silent call iced#buffer#error#init()
  silent call iced#nrepl#reset()
  silent call iced#nrepl#change_current_session('clj')
  let g:vim_iced_home = expand('<sfile>:p:h')
endfunction " }}}
function s:teardown() abort " {{{
  if filereadable(s:temp_foo)
    call delete(s:temp_foo)
  endif

  if filereadable(s:temp_bar)
    call delete(s:temp_bar)
  endif
endfunction " }}}

function! s:suite.done_test() abort
  call s:setup()
  let g:iced#hook = {'test_finished': {
        \ 'type': 'function', 'exec': {v -> s:holder.run(v)}}}
  let dummy_errors = [
        \ {'lnum': 123, 'filename': s:temp_foo, 'expected': 'foo', 'actual': 'bar', 'text': 'foo test', 'var': 'foo_var'},
        \ {'lnum': 234, 'filename': s:temp_bar, 'expected': 'bar', 'actual': 'baz', 'text': 'bar test', 'var': 'bar_var'},
        \ ]

  call iced#nrepl#test#done({
        \ 'errors': dummy_errors,
        \ 'summary': {'is_success': v:false, 'summary': 'dummy summary'},
        \ })

   call s:assert.equals(s:sign.list_all(), [
         \ {'lnum': 123, 'file': s:temp_foo, 'name': 'iced_error', 'group': 'foo_var'},
         \ {'lnum': 234, 'file': s:temp_bar, 'name': 'iced_error', 'group': 'bar_var'},
         \ ])
   call s:assert.equals(s:qf.get_last_args()['list'], dummy_errors)
   call s:assert.equals(s:holder.get_args(), [[{
         \ 'result': 'failed',
         \ 'summary': 'dummy summary'}]])

   let g:iced#hook = {}
   call s:teardown()
endfunction

function! s:suite.test_vars_by_ns_name_test() abort
	call s:setup()
  let test_vars = {'foo': {}, 'bar': {'test': ''}, 'baz': {'test': 'test'}}
  call s:ch.mock({
       \ 'status_value': 'open',
       \ 'relay': {msg -> (msg['op'] ==# 'ns-vars-with-meta')
       \           ? {'status': ['done'], 'ns-vars-with-meta': test_vars}
       \           : {'status': ['done']}}})

  let p = iced#nrepl#test#test_vars_by_ns_name('foo.core', {v -> s:holder.run(v)})
	call iced#promise#wait(p)

	let ret = s:holder.get_args()[0][0]
  call s:assert.equals(copy(sort(ret)), ['bar', 'baz'])
	call s:teardown()
endfunction

function! s:suite.test_vars_by_ns_name_error_test() abort
  call s:setup()
  call s:ch.mock({
       \ 'status_value': 'open',
       \ 'relay': {msg -> {'status': ['done']}}})

	let p = iced#nrepl#test#test_vars_by_ns_name('foo.core', {v -> s:holder.run(v)})
	call iced#promise#wait(p)

  let ret = s:holder.get_args()[0][0]
  call s:assert.true(empty(ret))
	call s:teardown()
endfunction

function! s:suite.fetch_test_vars_by_function_under_cursor_test() abort
  let test = {}
  function! test.relay(msg) abort
    if a:msg['op'] ==# 'eval'
      return {'status': ['done'], 'value': '#''foo.bar/baz'}
    elseif a:msg['op'] ==# 'ns-vars-with-meta'
      return {'status': ['done'], 'ns-vars-with-meta': {
           \   'foo-test': {'test': ''},
           \   'bar-test': {'test': ''},
           \   'baz-test': {'test': ''},
           \   'baz-test-fn': {}}}
    else
      return {'status': ['done']}
    endif
  endfunction

  function! test.result_callback(var_name, test_vars) abort
    let self.result = {'var_name': a:var_name, 'test_vars': a:test_vars}
  endfunction

  call s:ch.mock({'status_value': 'open', 'relay': test.relay})
  call s:buf.start_dummy([
      \ '(ns foo.bar)',
      \ '(defn baz [] "baz" |)'])
  let p = iced#nrepl#test#fetch_test_vars_by_function_under_cursor('foo.bar', test.result_callback)
	call iced#promise#wait(p)

  call s:assert.equals(test.result['var_name'], 'baz')
  call s:assert.equals(test.result['test_vars'], ['foo.bar/baz-test'])
  call s:buf.stop_dummy()
endfunction

" ==============================================
" =iced#nrepl#test#under_cursor
" ==============================================

function! s:build_under_cursor_relay() abort
  let d = {'last_var_query': {}}

  function! d.relay(opts, msg) abort
    let op = a:msg['op']

    let ns = get(a:opts, 'ns', 'foo.bar-test')
    let var = get(a:opts, 'var', 'baz-test')
    let eval_value = get(a:opts, 'eval', printf('#''%s/%s', ns, var))

    let tmp = {}
    let tmp[var] = {'test': ''}
    let ns_vars_value = get(a:opts, 'ns-vars-with-meta', copy(tmp))

    let tmp = {}
    let tmp[ns] = {}
    let tmp[ns][var] = get(a:opts, 'test-results', [])
    let test_var_query_value = get(a:opts, 'test-var-query', copy(tmp))

    if op ==# 'eval'
      return {'status': ['done'], 'value': eval_value}
    elseif op ==# 'ns-vars-with-meta'
      return {'status': ['done'], 'ns-vars-with-meta': ns_vars_value}
    elseif op ==# 'test-var-query'
      let self.last_var_query = a:msg['var-query']
      return {'status': ['done'], 'results': test_var_query_value}
    elseif op ==# 'ns-path'
      return {'status': ['done'], 'path': s:temp_foo}
    endif
    return {'status': ['done']}
  endfunction

  function! d.get_last_var_query() abort
    return self.last_var_query
  endfunction

  return d
endfunction

function! s:suite.under_cursor_with_test_var_success_test() abort
  call s:setup({'no_temp_files': v:true})
  let r = s:build_under_cursor_relay()
  let opts = {
        \ 'test-results': [{'context': 'dummy context',
        \                   'index': 0,
        \                   'ns': 'foo.bar-test',
        \                   'message': '',
        \                   'type': 'pass',
        \                   'var': 'baz-test'}]
        \ }

  call s:ch.mock({'status_value': 'open', 'relay': {v -> r.relay(opts, v)}})
  call s:buf.start_dummy(['(ns foo.bar-test)', '(some codes|)'])

  let p = iced#nrepl#test#under_cursor()
	call iced#promise#wait(p)

  call s:assert.equals(s:qf.get_last_args()['list'], [])

  call s:assert.equals(r.get_last_var_query(), {
        \ 'ns-query': {'exactly': ['foo.bar-test']},
        \ 'exactly': ['foo.bar-test/baz-test'],
        \ })

  call s:buf.stop_dummy()
  call s:teardown()
endfunction

function! s:suite.under_cursor_with_test_var_failure_test() abort
  call s:setup()
  let r = s:build_under_cursor_relay()
  let opts = {
        \ 'test-results': [{'context': 'dummy context',
        \                   'index': 0,
        \                   'ns': 'foo.bar-test',
        \                   'file': s:temp_foo,
        \                   'expected': "true\n",
        \                   'actual': "false\n",
        \                   'line': 1,
        \                   'message': '',
        \                   'type': 'fail',
        \                   'var': 'baz-test'}]
        \ }

  call s:ch.mock({'status_value': 'open', 'relay': {v -> r.relay(opts, v)}})
  call s:buf.start_dummy(['(ns foo.bar-test)', '(some codes|)'])

  let p = iced#nrepl#test#under_cursor()
	call iced#promise#wait(p)

  call s:assert.equals(s:qf.get_last_args()['list'], [
       \ {'lnum': 1,
       \  'actual': 'false',
       \  'expected': 'true',
       \  'type': 'E',
       \  'text': 'baz-test: dummy context',
       \  'filename': s:temp_foo,
       \  'var': 'baz-test'}
       \ ])
  call s:assert.equals(s:sign.list_all(), [
        \ {'lnum': 1, 'file': s:temp_foo, 'name': 'iced_error', 'group': 'baz-test'},
        \ ])
  call s:assert.equals(r.get_last_var_query(), {
        \ 'ns-query': {'exactly': ['foo.bar-test']},
        \ 'exactly': ['foo.bar-test/baz-test'],
        \ })

  call s:buf.stop_dummy()
  call s:teardown()
endfunction

function! s:suite.under_cursor_with_non_test_var_and_test_ns_test() abort
  call s:setup({'no_temp_files': v:true})
  let r = s:build_under_cursor_relay()
  let opts = {'eval': '#''foo.bar-test/non-existing'}

  call s:ch.mock({'status_value': 'open', 'relay': {v -> r.relay(opts, v)}})
  call s:buf.start_dummy(['(ns foo.bar-test)', '(some codes|)'])

  let p = iced#nrepl#test#under_cursor()
	call iced#promise#wait(p)

  call s:assert.equals(s:qf.get_last_args()['list'], [])
  call s:assert.equals(r.get_last_var_query(), {})

  call s:buf.stop_dummy()
  call s:teardown()
endfunction

function! s:suite.under_cursor_with_non_test_var_and_non_test_ns_test() abort
  call s:setup()
  let r = s:build_under_cursor_relay()
  let opts = {
        \ 'eval': '#''foo.bar/var',
        \ 'ns-vars-with-meta': {'var-test1': {'test': ''}, 'var-test2': {'test': ''}, 'var-test3': {}},
        \ 'test-results': [{'context': 'dummy context',
        \                   'ns': 'dummy-ns',
        \                   'index': 0, 'message': '',
        \                   'type': 'pass',
        \                   'var': 'dummy-var'}],
        \ }

  call s:ch.mock({'status_value': 'open', 'relay': {v -> r.relay(opts,v)}})
  call s:buf.start_dummy(['(ns foo.bar)', '(some codes|)'])

  let p = iced#nrepl#test#under_cursor()
  call iced#promise#wait(p)

  call s:assert.equals(s:qf.get_last_args()['list'], [])
  call s:assert.equals(r.get_last_var_query(), {
        \ 'ns-query': {'exactly': ['foo.bar-test']},
        \ 'exactly': ['foo.bar-test/var-test1', 'foo.bar-test/var-test2'],
        \ })

  call s:buf.stop_dummy()
  call s:teardown()
endfunction

" ==============================================
" =iced#nrepl#test#under_cursor (plain)
" ==============================================

function! s:plain_test_relay(edn, msg) abort
  let op = get(a:msg, 'op')
  if op ==# 'describe'
    return {'status': ['done'], 'ops': {}}
  elseif op ==# 'eval'
    if get(a:msg, 'code', '') ==# '(some codes)'
      return {'status': ['done'], 'value': "#'foo/bar"}
    else
      return {'status': ['done'], 'value': a:edn}
    endif
  endif
  return {'status': ['done']}
endfunction

function! s:suite.under_cursor_with_plain_nrepl_success_test() abort
  call s:setup()
  call iced#system#reset_component('job')

  let edn = '{:summary {:fail 0, :var 1, :error 0, :pass 1, :test 1}, :results {"foo.core" {"bar-success" ({:type :pass, :expected "1", :actual "1", :message nil, :ns "foo.core", :var "bar-success"})}}, :testing-ns "foo.core"}'
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:plain_test_relay', [edn])})
  call s:buf.start_dummy(['(ns foo.bar)', '(some codes|)'])

  let p = iced#nrepl#test#under_cursor()
  call iced#promise#wait(p)
  call s:assert.equals(s:qf.get_last_args()['list'], [])

  call s:buf.stop_dummy()
  call s:teardown()
  call iced#system#get('edn').close()
endfunction

function! s:suite.under_cursor_with_plain_nrepl_fail_test() abort
  call s:setup()
  call iced#system#reset_component('job')

  let edn = '{:summary {:fail 1, :var 1, :error 0, :pass 0, :test 1}, :results {"foo.core" {"bar-fail" ({:type :fail, :expected "1", :actual "2", :message nil, :ns "foo.core", :var "bar-fail", :file "dummy"})}}, :testing-ns "foo.core"}'
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:plain_test_relay', [edn])})
  call s:buf.start_dummy(['(ns foo.bar)', '(some codes|)'])

  let p = iced#nrepl#test#under_cursor()
  call iced#promise#wait(p)
  call s:assert.equals(s:qf.get_last_args()['list'], [
        \ {'type': 'E', 'expected': '1', 'actual': '2', 'filename': 'dummy',
        \  'text': 'bar-fail', 'var': 'bar-fail'},
        \ ])

  call s:buf.stop_dummy()
  call s:teardown()
  call iced#system#get('edn').close()
endfunction

function! s:suite.under_cursor_with_plain_nrepl_error_test() abort
  call s:setup()
  call iced#system#reset_component('job')

  let edn = '{:summary {:fail 0, :var 1, :error 1, :pass 0, :test 1}, :results {"foo.core" {"bar-error" ({:type :error, :expected "1", :actual "class clojure.lang.ExceptionInfo: foo{:bar 3}", :message nil, :ns "foo.core", :var "bar-error", :file "dummy"})}}, :testing-ns "foo.core"}'
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:plain_test_relay', [edn])})
  call s:buf.start_dummy(['(ns foo.bar)', '(some codes|)'])

  let p = iced#nrepl#test#under_cursor()
  call iced#promise#wait(p)
  call s:assert.equals(s:qf.get_last_args()['list'], [
        \ {'type': 'E', 'expected': '1', 'actual': 'class clojure.lang.ExceptionInfo: foo{:bar 3}', 'filename': 'dummy',
        \  'text': 'bar-error', 'var': 'bar-error'},
        \ ])

  call s:buf.stop_dummy()
  call s:teardown()
  call iced#system#get('edn').close()
endfunction

" ==============================================
" =iced#nrepl#test#ns
" ==============================================

function! s:suite.ns_test() abort
  call s:setup()

  let r = s:build_under_cursor_relay()
  let opts = {'test-results': [{
        \ 'context': 'dummy context',
        \ 'ns': 'foo.bar-test',
        \ 'file': s:temp_foo,
        \ 'expected': "true\n",
        \ 'actual': "false\n",
        \ 'line': 1,
        \ 'index': 0, 'message': '',
        \ 'type': 'fail',
        \ 'var': 'dummy-var'}],
        \ }

  call s:ch.mock({'status_value': 'open', 'relay': {v -> r.relay(opts,v)}})
  call s:buf.start_dummy(['(ns foo.bar-test)', '(some codes|)'])

  let p = iced#nrepl#test#ns()
	call iced#promise#wait(p)

  call s:assert.equals(s:qf.get_last_args()['list'], [{
        \ 'lnum': 1,
        \ 'actual': 'false',
        \ 'expected': 'true',
        \ 'type': 'E',
        \ 'text': 'dummy-var: dummy context',
        \ 'filename': s:temp_foo,
        \ 'var': 'dummy-var',
        \ }])
  call s:assert.equals(r.get_last_var_query(), {
        \ 'ns-query': {'exactly': ['foo.bar-test']},
        \ })

  call s:buf.stop_dummy()
  call s:teardown()
  call iced#system#get('edn').close()
endfunction

function! s:suite.ns_with_non_test_ns_test() abort
  call s:setup({'no_temp_files': v:true})

  let r = s:build_under_cursor_relay()
  let opts = {
        \ 'test-results': [{'context': 'dummy context',
        \                   'ns': 'foo.bar-test',
        \                   'index': 0, 'message': '',
        \                   'type': 'pass',
        \                   'var': 'dummy-var'}],
        \ 'ns-vars-with-meta': {},
        \ }

  call s:ch.mock({'status_value': 'open', 'relay': {v -> r.relay(opts,v)}})
  "" NOTE: the ns name does not end with '-test'
  call s:buf.start_dummy(['(ns bar.baz)', '(some codes|)'])

  let p = iced#nrepl#test#ns()
	call iced#promise#wait(p)

  call s:assert.equals(s:qf.get_last_args()['list'], [])
  call s:assert.equals(r.get_last_var_query(), {
        \ 'ns-query': {'exactly': ['bar.baz-test']}})

  call s:buf.stop_dummy()
  call s:teardown()
  call iced#system#get('edn').close()
endfunction

" ==============================================
" =iced#nrepl#test#ns (plain)
" ==============================================

function! s:suite.ns_with_plain_success_test() abort
  call s:setup()
  call iced#system#reset_component('job')
  call s:buf.start_dummy(['(ns bar.baz|)'])

  let edn = '{:summary {:fail 0, :var 1, :error 0, :pass 1, :test 1}, :results {"foo.core" {"bar-success" ({:type :pass, :expected "1", :actual "1", :message nil, :ns "foo.core", :var "bar-success"})}}, :testing-ns "foo.core"}'
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:plain_test_relay', [edn])})

  let p = iced#nrepl#test#ns()
  call iced#promise#wait(p)

  call s:assert.equals(s:qf.get_last_args()['list'], [])

  call s:buf.stop_dummy()
  call s:teardown()
  call iced#system#get('edn').close()
endfunction

function! s:suite.ns_with_plain_fail_test() abort
  call s:setup()
  call iced#system#reset_component('job')
  call s:buf.start_dummy(['(ns bar.baz|)'])

  let edn = '{:summary {:fail 2, :var 1, :error 0, :pass 0, :test 1}, :results {"foo.core" {"bar-fail" ({:type :fail, :expected "1", :actual "2", :file "dummy", :message nil, :ns "foo.core", :var "bar-fail"} {:type :fail, :expected "2", :actual "3", :file "dummy", :message nil, :ns "foo.core", :var "baz-fail"})}}, :testing-ns "foo.core"}'
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:plain_test_relay', [edn])})

  let p = iced#nrepl#test#ns()
  call iced#promise#wait(p)

  call s:assert.equals(s:qf.get_last_args()['list'], [
        \ {'type': 'E', 'expected': '1', 'actual': '2', 'filename': 'dummy', 'text': 'bar-fail', 'var': 'bar-fail'},
        \ {'type': 'E', 'expected': '2', 'actual': '3', 'filename': 'dummy', 'text': 'baz-fail', 'var': 'baz-fail'},
        \ ])

  call s:buf.stop_dummy()
  call s:teardown()
  call iced#system#get('edn').close()
endfunction

" ==============================================
" =iced#nrepl#test#all
" ==============================================

function! s:suite.all_test() abort
  call s:setup()
  let r = s:build_under_cursor_relay()
  let opts = {'test-results': [{
        \ 'context': 'dummy context',
        \ 'ns': 'dummy-ns',
        \ 'file': s:temp_foo,
        \ 'expected': "true\n",
        \ 'actual': "false\n",
        \ 'line': 1,
        \ 'index': 0, 'message': '',
        \ 'type': 'fail',
        \ 'var': 'dummy-var'}]}

  call s:ch.mock({'status_value': 'open', 'relay': {v -> r.relay(opts,v)}})
  call s:buf.start_dummy(['(ns foo.bar)', '(some codes|)'])

  let p = iced#nrepl#test#all()
	call iced#promise#wait(p)

  call s:assert.equals(s:qf.get_last_args()['list'], [{
        \ 'lnum': 1,
        \ 'actual': 'false',
        \ 'expected': 'true',
        \ 'type': 'E',
        \ 'text': 'dummy-var: dummy context',
        \ 'filename': s:temp_foo,
        \ 'var': 'dummy-var',
        \ }])
  call s:assert.equals(r.get_last_var_query(), {
        \ 'ns-query': {'load-project-ns?': 'true', 'project?': 'true'}})

  call s:buf.stop_dummy()
  call s:teardown()
  call iced#system#get('edn').close()
endfunction

function! s:suite.all_with_plain_success_test() abort
  call s:setup()
  call iced#system#reset_component('job')
  call s:buf.start_dummy(['(ns bar.baz|)'])

  let edn = '{:summary {:fail 0, :var 1, :error 0, :pass 1, :test 1}, :results {"foo.core" {"bar-success" ({:type :pass, :expected "1", :actual "1", :message nil, :ns "foo.core", :var "bar-success"})}}, :testing-ns "foo.core"}'
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:plain_test_relay', [edn])})

  let p = iced#nrepl#test#all()
  call iced#promise#wait(p)

  call s:assert.equals(s:qf.get_last_args()['list'], [])

  call s:buf.stop_dummy()
  call s:teardown()
  call iced#system#get('edn').close()
endfunction

function! s:suite.all_with_plain_fail_test() abort
  call s:setup()
  call iced#system#reset_component('job')
  call iced#system#reset_component('edn')
  call s:buf.start_dummy(['(ns bar.baz|)'])

  let edn = '{:summary {:fail 2, :var 1, :error 0, :pass 0, :test 1}, :results {"foo.core" {"bar-fail" ({:type :fail, :expected "1", :actual "2", :file "dummy", :message nil, :ns "foo.core", :var "bar-fail"} {:type :fail, :expected "2", :actual "3", :file "dummy", :message nil, :ns "foo.core", :var "baz-fail"})}}, :testing-ns "foo.core"}'
  call s:ch.mock({'status_value': 'open', 'relay': funcref('s:plain_test_relay', [edn])})

  let p = iced#nrepl#test#all()
  call iced#promise#wait(p)

  call s:assert.equals(s:qf.get_last_args()['list'], [
        \ {'type': 'E', 'expected': '1', 'actual': '2', 'filename': 'dummy', 'text': 'bar-fail', 'var': 'bar-fail'},
        \ {'type': 'E', 'expected': '2', 'actual': '3', 'filename': 'dummy', 'text': 'baz-fail', 'var': 'baz-fail'},
        \ ])

  call s:buf.stop_dummy()
  call s:teardown()
  call iced#system#get('edn').close()
endfunction

" ==============================================
" =iced#nrepl#test#redo
" ==============================================

function! s:suite.redo_test() abort
  call s:setup()

  let test = {'redo_msg': {}}
  function! test.relay(msg) abort
    if a:msg.op ==# 'retest'
      let self.redo_msg = a:msg
      return {'status': ['done'], 'results': {
            \ 'foo.bar-test': {
            \   'baz-test': [{'context': 'dummy context',
            \                 'ns': 'dummy-ns',
            \                 'file': s:temp_foo,
            \                 'expected': "true\n",
            \                 'actual': "false\n",
            \                 'line': 1,
            \                 'index': 0, 'message': '',
            \                 'type': 'fail',
            \                 'var': 'dummy-var'}],
            \ }}}
    elseif a:msg.op ==# 'ns-path'
      return {'status': ['done'], 'path': s:temp_foo}
    endif
    return {'status': ['done']}
  endfunction
  function! test.get_redo_msg() abort
    return self.redo_msg
  endfunction

  call s:ch.mock({'status_value': 'open', 'relay': {v -> test.relay(v)}})
  call iced#nrepl#set_session('clj', 'clj-session')
  call iced#nrepl#change_current_session('clj')

  let p = iced#nrepl#test#redo()
  call iced#promise#wait(p)

  call s:assert.equals(s:qf.get_last_args()['list'], [{
        \ 'lnum': 1,
        \ 'actual': 'false',
        \ 'expected': 'true',
        \ 'type': 'E',
        \ 'text': 'dummy-var: dummy context',
        \ 'filename': s:temp_foo,
        \ 'var': 'dummy-var',
        \ }])
  let redo_msg = test.get_redo_msg()
  call s:assert.equals(redo_msg['session'], 'clj-session')
  call s:assert.equals(redo_msg['op'], 'retest')

  call s:teardown()
endfunction

function! s:suite.spec_check_test() abort
  let test = {}
  function! test.relay(msg) abort
    if a:msg.op ==# 'eval'
      return {'status': ['done'], 'value': '#''foo.bar/baz'}
    elseif a:msg.op ==# 'iced-spec-check'
      return {'status': ['done'], 'result': 'OK', 'num-tests': a:msg['num-tests']}
    endif
    return {'status': ['done']}
  endfunction

  call s:ch.mock({'status_value': 'open', 'relay': test.relay})
  call s:io.mock()
  call s:buf.start_dummy(['(ns foo.bar-test)', '(some codes|)'])

  let p = iced#nrepl#test#spec_check(123)
	call iced#promise#wait(p)

  call s:assert.equals(s:io.get_last_args(), {
        \ 'echomsg': {'hl': 'MoreMsg', 'text': 'foo.bar/baz: Ran 123 tests. Passed.'},
        \ })

  call s:buf.stop_dummy()
endfunction

function! s:suite.spec_check_failure_test() abort
  let test = {}
  function! test.relay(msg) abort
    if a:msg.op ==# 'eval'
      return {'status': ['done'], 'value': '#''foo.bar/baz'}
    elseif a:msg.op ==# 'iced-spec-check'
      return {'status': ['done'],
            \ 'result': 'NG',
            \ 'error': 'dummy message',
            \ 'failed-input': 'dummy fail',
            \ 'num-tests': a:msg['num-tests']}
    endif
    return {'status': ['done']}
  endfunction

  call s:ch.mock({'status_value': 'open', 'relay': test.relay})
  call s:io.mock()
  call s:buf.start_dummy(['(ns foo.bar-test)', '(some codes|)'])

  let p = iced#nrepl#test#spec_check(123)
	call iced#promise#wait(p)

  call s:assert.equals(s:io.get_last_args(), {
        \ 'echomsg': {'hl': 'ErrorMsg', 'text': 'foo.bar/baz: Ran 123 tests. Failed because ''dummy message'' with dummy fail args.'},
        \ })

  call s:buf.stop_dummy()
endfunction
