
# rpn86

A reverse polish notation/postfix evaluator
Currently only supports positive numbers                          

## Building

```
    yasm -f elf64 rpn86.asm -o rpn86.o
    gcc -m64 rpn86.o -o rpn86 -fno-pie -fno-plt
```

## Running

```
./rpn86
Enter a Reverse Polish notation expression:
10 5 +
Result is 15!
```

```
./rpn86
Enter a Reverse Polish notation expression:
10 5 + 5 * 5 /
Result is 15!
```