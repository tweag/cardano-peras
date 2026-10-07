# turn off the ouroboros packages' source-repository stanzas
total_lines="$(wc -l < cabal.project)"
start_line="$((total_lines - 6))"

sed -i "${start_line},\$s/^/--/" cabal.project
sed -i "53s/^--//" cabal.project

# reverse
function reverse {
  sed -i "${start_line},\$s/^--//" cabal.project
  sed -i "53s/^/--/" cabal.project
}

trap reverse EXIT

cabal build cardano-node

