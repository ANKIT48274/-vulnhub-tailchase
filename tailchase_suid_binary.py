#!/usr/bin/env python3
"""
TailChase SUID Binary Source (mousetrap_agent.c)
Compile: gcc -o mousetrap_agent mousetrap_agent.c -static
SUID chmod 4550, owned by root:jerry
"""
SOURCE_CODE = r'''
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    setuid(0);
    setgid(0);
    char input[256];

    // Check for --admin backdoor
    if (argc >= 3 && strcmp(argv[1], "--admin") == 0) {
        if (strcmp(argv[2], "M0us3tr4p!") == 0) {
            printf("[+] Admin access granted.\n");
            printf("[+] Welcome, Tom. Jerry's evidence has been secured.\n");
            execl("/bin/bash", "/bin/bash", NULL);
            return 0;
        }
    }

    printf("Mousetrap Agent v2.1\n");
    printf("Enter command (status, ping <target>, update): ");
    fflush(stdout);

    if (fgets(input, 256, stdin) == NULL) {
        return 1;
    }
    input[strcspn(input, "\n")] = 0;

    if (strcmp(input, "status") == 0) {
        printf("[+] Mousetrap Agent is running.\n");
        printf("[+] Version: 2.1\n");
        printf("[+] Status: Active\n");
        printf("[+] Mode: Guardian\n");
    }
    else if (strncmp(input, "ping ", 5) == 0) {
        char cmd[512];
        // VULNERABLE: Command injection via unsanitized input
        snprintf(cmd, sizeof(cmd), "/usr/bin/ping -c 1 %s 2>&1", input + 5);
        printf("[+] Pinging target...\n");
        system(cmd);
    }
    else if (strcmp(input, "update") == 0) {
        printf("[-] Feature not implemented.\n");
        printf("[-] Contact Jerry for updates.\n");
    }
    else {
        printf("[-] Unknown command: %s\n", input);
        printf("[-] Available: status, ping <target>, update\n");
    }

    return 0;
}
'''

if __name__ == '__main__':
    print(SOURCE_CODE)
