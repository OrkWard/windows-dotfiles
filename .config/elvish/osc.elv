# osc.elv: terminal OSC helpers (clipboard, WezTerm user vars).
# Elvish has no base64 builtin, so it is implemented here.

use str

var -chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

# Base64-encode the UTF-8 bytes of $s.
fn base64 {|s|
  var b = [(str:to-utf8-bytes $s | each {|h| num $h })]
  var n = (count $b)
  var out = []
  var i = 0
  while (< $i $n) {
    var rem = (- $n $i)
    var b1 = (if (> $rem 1) { put $b[(+ $i 1)] } else { put 0 })
    var b2 = (if (> $rem 2) { put $b[(+ $i 2)] } else { put 0 })
    var v = (+ (* $b[$i] 65536) (* $b1 256) $b2)
    var c3 = (% $v 64)
    set v = (/ (- $v $c3) 64)
    var c2 = (% $v 64)
    set v = (/ (- $v $c2) 64)
    var c1 = (% $v 64)
    var c0 = (/ (- $v $c1) 64)
    set out = [$@out $-chars[$c0] $-chars[$c1]]
    set out = [$@out (if (> $rem 1) { put $-chars[$c2] } else { put '=' })]
    set out = [$@out (if (> $rem 2) { put $-chars[$c3] } else { put '=' })]
    set i = (+ $i 3)
  }
  str:join '' $out
}

# Copy $s to the system clipboard via OSC 52.
fn copy {|s|
  print "\e]52;c;"(base64 $s)"\a"
}

# Set a WezTerm user var. No-op outside WezTerm.
fn set-user-var {|name value|
  if (not-eq $E:TERM_PROGRAM WezTerm) {
    return
  }
  print "\e]1337;SetUserVar="$name"="(base64 $value)"\a"
}
