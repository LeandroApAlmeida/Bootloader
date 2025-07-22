Bootloader de 3 estágios que implementa um sistema operacional fictício denominado de fakenix. O projeto visa o aprendizado da linguagem de baixo nível Assembly para arquitetura x86 e firmware BIOs.

Não foi desenvolvido um sistema operacional real, e, no lugar de carregar o kernel de um, se carrega uma versão do Jogo da Cobrinha em modo real, para demonstrar como a memória para um programa é alocada fisicamente quando não se tem um sistema operacional gerenciando o computador.

Se gerar uma imagem de disco do sistema Fakenix, em modo Raw, usando o programa Image Writer, e tiver um computador que usa o antigo firmware BIOS, é possível jogar, mesmo que este computador não tenha um HD, desde que permita dar boot por via USB. Ao dar boot com uma pendrive, por exemplo, o Fakenix passa a ser executado no lugar do sistema operacional.


https://github.com/user-attachments/assets/54848c11-b266-454a-84c1-2512cd05a1e0

