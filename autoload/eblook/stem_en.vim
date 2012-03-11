scriptencoding cp932

function! eblook#stem_en#Stem(word)
  let lword = tolower(a:word)
  let stemmed = []
  if lword !=# a:word
    call add(stemmed, lword)
  endif

  let res = s:StemHeuristics(lword)
  for w in res
    call s:AddNew(stemmed, w)
  endfor

  if g:eblook_stemming == 2 && exists(':PorterStem')
    let res = s:StemPorter(lword)
  else
    let res = s:StemUsingRules(lword)
  endif
  for w in res
    call s:AddNew(stemmed, w)
  endfor

  return sort(stemmed, 's:CompareLen')
endfunction

function! s:AddNew(lis, x)
  if index(a:lis, a:x) == -1
    return add(a:lis, a:x)
  endif
  return a:lis
endfunction

function! s:CompareLen(i1, i2)
  return len(a:i1) - len(a:i2)
endfunction

" 動詞/形容詞の活用形と名詞の複数形の活用語尾を取り除く。
" 与えられた語の原形として可能性のある語のリストを返す。
" (lookupのstem-english.elのstem:extraからの移植)
function! s:StemHeuristics(word)
  let irr = get(s:irregular_verb_alist, a:word)
  if type(irr) == type([])
    return irr
  endif

  if a:word ==# 'as'
    return ['as']
  endif

  let rules = [
    \['\([^aeiou]\)\1e\%(r\|st\)$', ['\1', '\1\1e']],
    \['\([^aeiou]\)ie\%(r\|st\)$', ['\1y', '\1ie']],
    \['e\%(r\|st\)$', ['', 'e']],
    \['ches$', ['ch', 'che']],
    \['shes$', ['sh', 'che']],
    \['ses$', ['s', 'se']],
    \['xes$', ['x', 'xe']],
    \['zes$', ['z', 'ze']],
    \['ves$', ['f', 'fe']],
    \['\([^aeiou]\)oes$', ['\1o', '\1oe']],
    \['\([^aeiou]\)ies$', ['\1y', '\1ie']],
    \['es$', ['', 'e']],
    \['s$', ['']],
    \['\([^aeiou]\)ied$', ['\1y', '\1ie']],
    \['\([^aeiou]\)\1ed$', ['\1', '\1\1e']],
    \['cked$', ['c', 'cke']],
    \['ed$', ['', 'e']],
    \['\([^aeiou]\)\1ing$', ['\1']],
    \['ing$', ['', 'e']],
  \]

  for rule in rules
    if a:word =~ rule[0]
      let ret = []
      for sub in rule[1]
	call add(ret, substitute(a:word, rule[0], sub, ''))
      endfor
      return ret
    endif
  endfor
  return []
endfunction

" 語尾補正ルールを使った語尾補正を行う
function! s:StemUsingRules(word)
  " 語尾補正ルールリスト (ebviewを参考に作成)
  let rules = [
    \['ies$', 'y'],
    \['ied$', 'y'],
    \['es$', ''],
    \['ting$', 'te'],
    \['ing$', ''],
    \['ing$', 'e'],
    \['ed$', 'e'],
    \['ed$', ''],
    \['id$', 'y'],
    \['ices$', 'ex'],
    \['ves$', 'fe'],
    \['s$', ''],
  \]

  let stemmed = []
  for rule in rules
    if a:word =~ rule[0]
      call add(stemmed, substitute(a:word, rule[0], rule[1], ''))
    endif
  endfor
  return stemmed
endfunction

" porter-stem.vimを使ったstemming
function! s:StemPorter(word)
  function! s:GetPorterStemFuncs()
    " porter-stem.vim<https://github.com/msbmsb/porter-stem.vim>の<SNR>番号取得
    " :PorterStemは<SID>を使ってないので:command結果からの取得は不可
    " http://d.hatena.ne.jp/thinca/20111228
    silent! redir => sliststr
    silent! scriptnames
    silent! redir END
    let slist = split(sliststr, "\n")
    call filter(slist, 'v:val =~ "porter-stem.vim"')
    let porterstem_sid = substitute(slist[0], '^\s*\(\d\+\):.*$', '\1', '')

    let s:Step1a = function('<SNR>' . porterstem_sid . '_Step1a')
    let s:Step1b = function('<SNR>' . porterstem_sid . '_Step1b')
    let s:Step1c = function('<SNR>' . porterstem_sid . '_Step1c')
    let s:Step2 = function('<SNR>' . porterstem_sid . '_Step2')
    let s:Step3 = function('<SNR>' . porterstem_sid . '_Step3')
    let s:Step4 = function('<SNR>' . porterstem_sid . '_Step4')
    let s:Step5a = function('<SNR>' . porterstem_sid . '_Step5a')
    let s:Step5b = function('<SNR>' . porterstem_sid . '_Step5b')

    function! s:Step1(word)
      let newword = s:Step1a(a:word)
      let newword = s:Step1b(newword)
      return s:Step1c(newword)
    endfunction

    function! s:Step5(word)
      let newword = s:Step5a(a:word)
      return s:Step5b(newword)
    endfunction
  endfunction

  if len(a:word) <= 2
    return []
  endif

  if !exists('s:Step1a')
    call s:GetPorterStemFuncs()
  endif

  " copy from GetWordStem()
  let newword = a:word

  " initial y fix
  let changedY = 0
  if newword[0] == 'y'
    let newword = 'Y'.newword[1:]
    let changedY = 1
  endif

  " Porter Stemming
  let newword1 = s:Step1(newword)
  let newword2 = s:Step2(newword1)
  let newword3 = s:Step3(newword2)
  let newword4 = s:Step4(newword3)
  let newword5 = s:Step5(newword4)

  let newwords = [newword1]
  call s:AddNew(newwords, newword2)
  call s:AddNew(newwords, newword3)
  call s:AddNew(newwords, newword4)
  call s:AddNew(newwords, newword5)

  if changedY
    call map(newwords, '"y" . v:val[1:]')
  endif

  return newwords
endfunction

" 不規則動詞と原形の連想配列"
let s:irregular_verb_alist = {
  \"abode": ["abide"],
  \"abided": ["abide"],
  \"alighted": ["alight"],
  \"arose": ["arise"],
  \"arisen": ["arise"],
  \"awoke": ["awake"],
  \"awaked": ["awake"],
  \"awoken": ["awake"],
  \"baby-sat": ["baby-sit"],
  \"backbit": ["backbite"],
  \"backbitten": ["backbite"],
  \"backslid": ["backslide"],
  \"backslidden": ["backslide"],
  \"was": ["be", "am", "is", "are"],
  \"were": ["be", "am", "is", "are"],
  \"been": ["be", "am", "is", "are"],
  \"bore": ["bear"],
  \"bare": ["bear"],
  \"borne": ["bear"],
  \"born": ["bear"],
  \"beat": ["beat"],
  \"beaten": ["beat"],
  \"befell": ["befall"],
  \"befallen": ["befall"],
  \"begot": ["beget"],
  \"begat": ["beget"],
  \"begotten": ["beget"],
  \"began": ["begin"],
  \"begun": ["begin"],
  \"begirt": ["begird"],
  \"begirded": ["begird"],
  \"beheld": ["behold"],
  \"bent": ["bend"],
  \"bended": ["bend"],
  \"bereaved": ["bereave"],
  \"bereft": ["bereave"],
  \"besought": ["beseech"],
  \"beseeched": ["beseech"],
  \"beset": ["beset"],
  \"bespoke": ["bespeak"],
  \"bespoken": ["bespeak"],
  \"bestrewed": ["bestrew"],
  \"bestrewn": ["bestrew"],
  \"bestrode": ["bestride"],
  \"bestrid": ["bestride"],
  \"bestridden": ["bestride"],
  \"bet": ["bet"],
  \"betted": ["bet"],
  \"betook": ["betake"],
  \"betaken": ["betake"],
  \"bethought": ["bethink"],
  \"bade": ["bid"],
  \"bid": ["bid"],
  \"bad": ["bid"],
  \"bedden": ["bid"],
  \"bided": ["bide"],
  \"bode": ["bide"],
  \"bound": ["bind"],
  \"bit": ["bite"],
  \"bitten": ["bite"],
  \"bled": ["bleed"],
  \"blended": ["blend"],
  \"blent": ["blend"],
  \"blessed": ["bless"],
  \"blest": ["bless"],
  \"blew": ["blow"],
  \"blown": ["blow"],
  \"blowed": ["blow"],
  \"bottle-fed": ["bottle-feed"],
  \"broke": ["break"],
  \"broken": ["break"],
  \"breast-fed": ["breast-feed"],
  \"bred": ["breed"],
  \"brought": ["bring"],
  \"broadcast": ["broadcast"],
  \"broadcasted": ["broadcast"],
  \"browbeat": ["browbeat"],
  \"browbeaten": ["browbeat"],
  \"built": ["build"],
  \"builded": ["build"],
  \"burned": ["burn"],
  \"burnt": ["burn"],
  \"burst": ["burst"],
  \"busted": ["bust"],
  \"bust": ["bust"],
  \"bought": ["buy"],
  \"cast": ["cast"],
  \"chid": ["chide"],
  \"chided": ["chide"],
  \"chidden": ["chide"],
  \"chose": ["choose"],
  \"chosen": ["choose"],
  \"clove": ["cleave"],
  \"cleft": ["cleave"],
  \"cleaved": ["cleave"],
  \"cloven": ["cleave"],
  \"clave": ["cleave"],
  \"clung": ["cling"],
  \"clothed": ["clothe"],
  \"clad": ["clothe"],
  \"colorcast": ["colorcast"],
  \"clorcasted": ["colorcast"],
  \"came": ["come"],
  \"come": ["come"],
  \"cost": ["cost"],
  \"costed": ["cost"],
  \"countersank": ["countersink"],
  \"countersunk": ["countersink"],
  \"crept": ["creep"],
  \"crossbred": ["crossbreed"],
  \"crowed": ["crow"],
  \"crew": ["crow"],
  \"cursed": ["curse"],
  \"curst": ["curse"],
  \"cut": ["cut"],
  \"dared": ["dare"],
  \"durst": ["dare"],
  \"dealt": ["deal"],
  \"deep-froze": ["deep-freeze"],
  \"deep-freezed": ["deep-freeze"],
  \"deep-frozen": ["deep-freeze"],
  \"dug": ["dig"],
  \"digged": ["dig"],
  \"dived": ["dive"],
  \"dove": ["dive"],
  \"did": ["do"],
  \"done": ["do"],
  \"drew": ["draw"],
  \"drawn": ["draw"],
  \"dreamed": ["dream"],
  \"dreamt": ["dream"],
  \"drank": ["drink"],
  \"drunk": ["drink"],
  \"dripped": ["drip"],
  \"dript": ["drip"],
  \"drove": ["drive"],
  \"drave": ["drive"],
  \"driven": ["drive"],
  \"dropped": ["drop"],
  \"dropt": ["drop"],
  \"dwelt": ["dwell"],
  \"dwelled": ["dwell"],
  \"ate": ["eat"],
  \"eaten": ["eat"],
  \"fell": ["fall"],
  \"fallen": ["fall"],
  \"fed": ["feed"],
  \"felt": ["feel"],
  \"fought": ["fight"],
  \"found": ["find"],
  \"fled": ["fly", "flee"],
  \"flung": ["fling"],
  \"flew": ["fly"],
  \"flied": ["fly"],
  \"flown": ["fly"],
  \"forbore": ["forbear"],
  \"forborne": ["forbear"],
  \"forbade": ["forbid"],
  \"forbad": ["forbid"],
  \"forbidden": ["forbid"],
  \"forecast": ["forecast"],
  \"forecasted": ["forecast"],
  \"forewent": ["forego"],
  \"foregone": ["forego"],
  \"foreknew": ["foreknow"],
  \"foreknown": ["foreknow"],
  \"foreran": ["forerun"],
  \"forerun": ["forerun"],
  \"foresaw": ["foresee"],
  \"foreseen": ["foresee"],
  \"foreshowed": ["foreshow"],
  \"foreshown": ["foreshow"],
  \"foretold": ["foretell"],
  \"forgot": ["forget"],
  \"forgotten": ["forget"],
  \"forgave": ["forgive"],
  \"forgiven": ["forgive"],
  \"forwent": ["forgo"],
  \"forgone": ["forgo"],
  \"forsook": ["forsake"],
  \"forsaken": ["forsake"],
  \"forswore": ["forswear"],
  \"forsworn": ["forswear"],
  \"froze": ["freeze"],
  \"frozen": ["freeze"],
  \"gainsaid": ["gainsay"],
  \"gelded": ["geld"],
  \"gelt": ["geld"],
  \"got": ["get"],
  \"gotten": ["get"],
  \"ghostwrote": ["ghostwrite"],
  \"ghostwritten": ["ghostwrite"],
  \"gilded": ["gild"],
  \"gilt": ["gild"],
  \"girded": ["gird"],
  \"girt": ["gird"],
  \"gave": ["give"],
  \"given": ["give"],
  \"gnawed": ["gnaw"],
  \"gnawn": ["gnaw"],
  \"went": ["go", "wend"],
  \"gone": ["go"],
  \"graved": ["grave"],
  \"graven": ["grave"],
  \"ground": ["grind"],
  \"gripped": ["grip"],
  \"gript": ["grip"],
  \"grew": ["grow"],
  \"grown": ["grow"],
  \"hamstrung": ["hamstring"],
  \"hamstringed": ["hamstring"],
  \"hung": ["hang"],
  \"hanged": ["hang"],
  \"had": ["have"],
  \"heard": ["hear"],
  \"heaved": ["heave"],
  \"hove": ["heave"],
  \"hewed": ["hew"],
  \"hewn": ["hew"],
  \"hid": ["hide"],
  \"hidden": ["hide"],
  \"hit": ["hit"],
  \"held": ["hold"],
  \"hurt": ["hurt"],
  \"indwelt": ["indwell"],
  \"inlaid": ["inlay"],
  \"inlet": ["inlet"],
  \"inputted": ["input"],
  \"input": ["input"],
  \"inset": ["inset"],
  \"insetted": ["inset"],
  \"interwove": ["interweave"],
  \"interweaved": ["interweave"],
  \"jigsawed": ["jigsaw"],
  \"jigsawn": ["jigsaw"],
  \"kept": ["keep"],
  \"knelt": ["kneel"],
  \"kneeled": ["kneel"],
  \"knitted": ["knit"],
  \"knit": ["knit"],
  \"knew": ["know"],
  \"known": ["know"],
  \"laded": ["lade"],
  \"laden": ["lade"],
  \"laid": ["lay"],
  \"led": ["lead"],
  \"leaned": ["lean"],
  \"leant": ["lean"],
  \"leaped": ["leap"],
  \"leapt": ["leap"],
  \"learned": ["learn"],
  \"learnt": ["learn"],
  \"left": ["leave"],
  \"lent": ["lend"],
  \"let": ["let"],
  \"lay": ["lie"],
  \"lain": ["lie"],
  \"lighted": ["light"],
  \"lit": ["light"],
  \"lip-read": ["lip-read"],
  \"lost": ["lose"],
  \"made": ["make"],
  \"meant": ["mean"],
  \"met": ["meet"],
  \"melted": ["melt"],
  \"methougt": ["methinks"],
  \"misbecame": ["misbecome"],
  \"misbecome": ["misbecome"],
  \"miscast": ["miscast"],
  \"miscasted": ["miscast"],
  \"misdealt": ["misdeal"],
  \"misdid": ["misdo"],
  \"misdone": ["misdo"],
  \"misgave": ["misgive"],
  \"misgiven": ["misgive"],
  \"mishit": ["mishit"],
  \"mislaid": ["mislay"],
  \"misled": ["mislead"],
  \"misread": ["misread"],
  \"misspelt": ["misspell"],
  \"missplled": ["misspell"],
  \"misspent": ["misspend"],
  \"mistook": ["mistake"],
  \"mistaken": ["mistake"],
  \"misunderstood": ["misunderstand"],
  \"mowed": ["mow"],
  \"mown": ["mow"],
  \"offset": ["offset"],
  \"outbid": ["outbid"],
  \"outbade": ["outbid"],
  \"outbidden": ["outbid"],
  \"outdid": ["outdo"],
  \"outdone": ["outdo"],
  \"outfought": ["outfight"],
  \"outgrew": ["outgrown"],
  \"outgrown": ["outgrown"],
  \"outlaid": ["outlay"],
  \"output": ["output"],
  \"outputted": ["output"],
  \"ooutputted": ["output"],
  \"outrode": ["outride"],
  \"outridden": ["outride"],
  \"outran": ["outrun"],
  \"outrun": ["outrun"],
  \"outsold": ["outsell"],
  \"outshone": ["outshine"],
  \"outshot": ["outshoot"],
  \"outwore": ["outwear"],
  \"outworn": ["outwear"],
  \"overbore": ["overbear"],
  \"overborne": ["overbear"],
  \"overbid": ["overbid"],
  \"overblew": ["overblow"],
  \"overblown": ["overblow"],
  \"overcame": ["overcome"],
  \"overcome": ["overcome"],
  \"overdid": ["overdo"],
  \"overdone": ["overdo"],
  \"overdrew": ["overdraw"],
  \"overdrawn": ["overdraw"],
  \"overdrank": ["overdrink"],
  \"overdrunk": ["overdrink"],
  \"overate": ["overeat"],
  \"overeaten": ["overeat"],
  \"overfed": ["overfeed"],
  \"overflowed": ["overflow"],
  \"overflown": ["overfly", "overflow"],
  \"overflew": ["overfly"],
  \"overgrew": ["overgrow"],
  \"overgrown": ["overgrow"],
  \"overhung": ["overhang"],
  \"overhanged": ["overhang"],
  \"ovearheard": ["overhear"],
  \"overlaid": ["overlay"],
  \"overleaped": ["overleap"],
  \"overleapt": ["overleap"],
  \"overlay": ["overlie"],
  \"overlain": ["overlie"],
  \"overpaid": ["overpay"],
  \"overrode": ["override"],
  \"overridden": ["override"],
  \"overran": ["overrun"],
  \"overrun": ["overrun"],
  \"oversaw": ["oversee"],
  \"overseen": ["oversee"],
  \"oversold": ["oversell"],
  \"overset": ["overset"],
  \"overshot": ["overshoot"],
  \"overspent": ["overspend"],
  \"overspread": ["overspread"],
  \"overtook": ["overtake"],
  \"overtaken": ["overtake"],
  \"overthrew": ["overthrow"],
  \"overthrown": ["overthrow"],
  \"overworked": ["overwork"],
  \"overwrought": ["overwork"],
  \"partook": ["partake"],
  \"partaken": ["partake"],
  \"paid": ["pay"],
  \"penned": ["pen"],
  \"pent": ["pen"],
  \"pinch-hit": ["pinch-hit"],
  \"pleaded": ["plead"],
  \"plead": ["plead"],
  \"pled": ["plead"],
  \"prepaid": ["prepay"],
  \"preset": ["preset"],
  \"proofread": ["proofread"],
  \"proved": ["prove"],
  \"proven": ["prove"],
  \"put": ["put"],
  \"quick-froze": ["quick-freeze"],
  \"quick-frozen": ["quick-freeze"],
  \"quit": ["quit"],
  \"quitted": ["quit"],
  \"read": ["read"],
  \"reaved": ["reave"],
  \"reft": ["reave"],
  \"rebound": ["rebind"],
  \"rebroadcast": ["rebroadcast"],
  \"rebroadcasted": ["rebroadcast"],
  \"rebuilt": ["rebuild"],
  \"recast": ["recast"],
  \"recasted": ["recast"],
  \"re-did": ["re-do"],
  \"re-done": ["re-do"],
  \"reeved": ["reeve"],
  \"rove": ["reeve"],
  \"reheard": ["rehear"],
  \"relaid": ["relay"],
  \"remade": ["remake"],
  \"rent": ["rend"],
  \"repaid": ["repay"],
  \"reread": ["reread"],
  \"reran": ["rerun"],
  \"rerun": ["rerun"],
  \"resold": ["resell"],
  \"reset": ["reset"],
  \"retook": ["retake"],
  \"retaken": ["retake"],
  \"retold": ["retell"],
  \"rethought": ["rethink"],
  \"rewound": ["rewind"],
  \"rewinded": ["rewind"],
  \"rewrote": ["rewrite"],
  \"rewritten": ["rewrite"],
  \"rid": ["ride"],
  \"ridded": ["rid"],
  \"rode": ["ride"],
  \"ridden": ["ride"],
  \"rang": ["ring"],
  \"rung": ["ring"],
  \"rose": ["rise"],
  \"risen": ["rise"],
  \"rived": ["rive"],
  \"riven": ["rive"],
  \"roughcast": ["roughcast"],
  \"roughhewed": ["roughhew"],
  \"roughhewn": ["roughhew"],
  \"ran": ["run"],
  \"run": ["run"],
  \"sawed": ["saw"],
  \"sawn": ["saw"],
  \"said": ["say"],
  \"saw": ["see"],
  \"seen": ["see"],
  \"sought": ["seek"],
  \"sold": ["sell"],
  \"sent": ["send"],
  \"set": ["set"],
  \"sewed": ["sew"],
  \"sewn": ["sew"],
  \"shook": ["shake"],
  \"shaken": ["shake"],
  \"shaved": ["shave"],
  \"shaven": ["shave"],
  \"sheared": ["shear"],
  \"shore": ["shear"],
  \"shorn": ["shear"],
  \"shed": ["shed"],
  \"shone": ["shine"],
  \"shined": ["shine"],
  \"shit": ["shit"],
  \"shat": ["shit"],
  \"shitted": ["shit"],
  \"shod": ["shoe"],
  \"shoed": ["shoe"],
  \"shot": ["shoot"],
  \"showed": ["show"],
  \"shown": ["show"],
  \"shredded": ["shred"],
  \"shred": ["shred"],
  \"shrank": ["shrink"],
  \"shrunk": ["shrink"],
  \"shrunken": ["shrink"],
  \"shrived": ["shrive"],
  \"shrove": ["shrive"],
  \"shriven": ["shrive"],
  \"shut": ["shut"],
  \"sight-read": ["sight-read"],
  \"simulcast": ["simulcast"],
  \"simulcasted": ["simulcast"],
  \"sang": ["sing"],
  \"sung": ["sing"],
  \"sank": ["sink"],
  \"sunk": ["sink"],
  \"sunken": ["sink"],
  \"sat": ["sit"],
  \"sate": ["sit"],
  \"slew": ["slay"],
  \"slain": ["slay"],
  \"slept": ["sleep"],
  \"slid": ["slide"],
  \"slidden": ["slide"],
  \"slunk": ["slink"],
  \"smelled": ["smell"],
  \"smelt": ["smell"],
  \"smote": ["smite"],
  \"smitten": ["smite"],
  \"smit": ["smite"],
  \"sowed": ["sow"],
  \"sown": ["sow"],
  \"spoke": ["speak"],
  \"spoken": ["speak"],
  \"sped": ["speed"],
  \"speeded": ["speed"],
  \"spelled": ["spell"],
  \"spelt": ["spell"],
  \"spellbound": ["spellbind"],
  \"spent": ["spend"],
  \"spilled": ["spill"],
  \"spilt": ["spill"],
  \"spun": ["spin"],
  \"span": ["spin"],
  \"spat": ["spit"],
  \"spit": ["spit"],
  \"split": ["split"],
  \"spoiled": ["spoil"],
  \"spoilt": ["spoil"],
  \"spoon-fed": ["spoon-feed"],
  \"spread": ["spread"],
  \"sprang": ["spring"],
  \"sprung": ["spring"],
  \"stood": ["stand"],
  \"staved": ["stave"],
  \"stove": ["stave"],
  \"stayed": ["stay"],
  \"staid": ["stay"],
  \"stole": ["steal"],
  \"stolen": ["steal"],
  \"stuck": ["stick"],
  \"stung": ["sting"],
  \"stank": ["stink"],
  \"stunk": ["stink"],
  \"strewed": ["strew"],
  \"strewn": ["strew"],
  \"strode": ["stride"],
  \"stridden": ["stride"],
  \"struck": ["strike"],
  \"stricken": ["strike"],
  \"strung": ["string"],
  \"strove": ["strive"],
  \"striven": ["strive"],
  \"sublet": ["sublet"],
  \"sunburned": ["sunburn"],
  \"sunburnt": ["sunburn"],
  \"swore": ["swear"],
  \"sware": ["swear"],
  \"sworn": ["swear"],
  \"sweat": ["sweat"],
  \"sweated": ["sweat"],
  \"swept": ["sweep"],
  \"swelled": ["swell"],
  \"swollen": ["swell"],
  \"swam": ["swim"],
  \"swum": ["swim"],
  \"swung": ["swing"],
  \"took": ["take"],
  \"taken": ["take"],
  \"taught": ["teach"],
  \"tore": ["tear"],
  \"torn": ["tear"],
  \"telecast": ["telecast"],
  \"telecasted": ["telecast"],
  \"told": ["tell"],
  \"thought": ["think"],
  \"thrived": ["thrive"],
  \"throve": ["thrive"],
  \"thriven": ["thrive"],
  \"threw": ["thrown"],
  \"thrown": ["thrown"],
  \"thrust": ["thrust"],
  \"tossed": ["toss"],
  \"tost": ["toss"],
  \"trod": ["tread"],
  \"treaded": ["tread"],
  \"trode": ["tread"],
  \"trodden": ["tread"],
  \"typecast": ["typecast"],
  \"typewrote": ["typewrite"],
  \"typewritten": ["typewrite"],
  \"unbent": ["unbend"],
  \"unbended": ["unbend"],
  \"unbound": ["unbind"],
  \"underbid": ["underbid"],
  \"underbidden": ["underbid"],
  \"undercut": ["undercut"],
  \"underwent": ["undergo"],
  \"undergone": ["undergo"],
  \"underlaid": ["underlay"],
  \"underlay": ["underlie"],
  \"underlain": ["underlie"],
  \"underpaid": ["underpay"],
  \"undersold": ["undersell"],
  \"undershot": ["undershoot"],
  \"understood": ["understand"],
  \"undertook": ["undertake"],
  \"undertaken": ["undertake"],
  \"underwrote": ["underwrite"],
  \"underwritten": ["underwrite"],
  \"undid": ["undo"],
  \"undone": ["undo"],
  \"undrew": ["undraw"],
  \"undrawn": ["undraw"],
  \"ungirded": ["ungird"],
  \"ungirt": ["ungird"],
  \"unlearnt": ["unlearn"],
  \"unlearned": ["unlearn"],
  \"unmade": ["unmake"],
  \"unsaid": ["unsay"],
  \"unstuck": ["unstick"],
  \"unstrung": ["unstring"],
  \"unwound": ["unwind"],
  \"upheld": ["uphold"],
  \"uprose": ["uprise"],
  \"uprisen": ["uprise"],
  \"upset": ["upset"],
  \"upswept": ["upsweep"],
  \"woke": ["wake"],
  \"waked": ["wake"],
  \"woken": ["wake"],
  \"waylaid": ["waylay"],
  \"wore": ["wear"],
  \"worn": ["wear"],
  \"wove": ["weave"],
  \"weaved": ["weave"],
  \"woven": ["weave"],
  \"wed": ["wed"],
  \"wedded": ["wed"],
  \"wept": ["weep"],
  \"wended": ["wend"],
  \"wetted": ["wet"],
  \"wet": ["wet"],
  \"won": ["win"],
  \"wound": ["wind"],
  \"winded": ["wind"],
  \"wiredrew": ["wiredraw"],
  \"wiredrawn": ["wiredraw"],
  \"wist": ["wit"],
  \"withdrew": ["withdraw"],
  \"withdrawn": ["withdraw"],
  \"withheld": ["withhold"],
  \"withstood": ["withstand"],
  \"worked": ["work"],
  \"wrought": ["work"],
  \"wrapped": ["wrap"],
  \"wrapt": ["wrap"],
  \"wrung": ["wring"],
  \"wrote": ["write"],
  \"writ": ["write"],
  \"written": ["write"],
\}
