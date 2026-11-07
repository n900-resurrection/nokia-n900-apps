TEST_NAME=age
need_pkg age
ok in-path sh -c 'command -v age && command -v age-keygen'
t version 'v1.2.1' sh -c 'age --version'
D=/home/user/age-test; rm -rf $D; mkdir -p $D; echo "secret n900 text" > $D/plain.txt
ok keygen sh -c "age-keygen -o $D/key.txt 2>/dev/null && grep -q AGE-SECRET-KEY $D/key.txt"
ok encrypt-for-key sh -c "age -r \$(age-keygen -y $D/key.txt) -o $D/plain.age $D/plain.txt && ! grep -q secret $D/plain.age"
t decrypt "secret n900 text" sh -c "age -d -i $D/key.txt $D/plain.age"
ok wrong-key-refused sh -c "age-keygen -o $D/other.txt 2>/dev/null; ! age -d -i $D/other.txt $D/plain.age"
rm -rf $D
summary
