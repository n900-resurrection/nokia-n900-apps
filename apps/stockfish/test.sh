TEST_NAME=stockfish
need_pkg stockfish
ok in-path sh -c 'command -v stockfish'
ok static-binary sh -c '! ldd /opt/stockfish/bin/stockfish 2>&1 | grep -q "not found"'
t uci-id 'id name Stockfish 11' sh -c 'printf "uci\nquit\n" | stockfish | grep "^id name"'
t best-move 'bestmove' sh -c 'printf "position startpos\ngo depth 6\n" | (cat; sleep 5; echo quit) | stockfish | grep -o "bestmove"'
# a mate in one: white Qh5 is mate (fool's mate position, black to have been mated is not it): 1.f3 e5 2.g4 Qh4# is black's; here white to move mates with Qxf7#
t finds-mate 'bestmove h5f7' sh -c 'printf "position fen r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 1\ngo depth 6\n" | (cat; sleep 5; echo quit) | stockfish | grep -o "bestmove h5f7"'
ok license test -r /opt/stockfish/share/doc/stockfish/Copying.txt
summary
