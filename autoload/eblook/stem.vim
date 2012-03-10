scriptencoding cp932

function! eblook#stem#stem(word)
  if a:word =~ '[^ -~]'
    return eblook#stem#stem_using_rules(a:word, g:eblook#stem_ja#rules)
    " TODO: 漢字部分のみにしたものを追加する
  else
    return eblook#stem#stem_using_rules(a:word, g:eblook#stem_en#rules)
  endif
endfunction

" 語尾補正ルールを使った語尾補正を行う
function! eblook#stem#stem_using_rules(word, rules)
  let stemmed = []
  for rule in a:rules
    if a:word =~ rule[0]
      call add(stemmed, substitute(a:word, rule[0], rule[1], ''))
    endif
  endfor
  return stemmed
endfunction
