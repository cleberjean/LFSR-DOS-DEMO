LFSR Visualization Demo for DOS and 8086 CPU
============================================

Um efeito clássico de *Fade In* e *Fade Out* gráfico escrito em **Assembly x86 puro (16-bits)** para o processador Intel 8086. O programa utiliza um algoritmo **LFSR (Linear Feedback Shift Register)** do tipo Galois para preencher e limpar a tela pixel por pixel de forma pseudo-aleatória, sem repetir coordenadas, simulando um efeito de "chuvisco" ou "estática" controlado.

O projeto roda em **Modo 13h** (320x200 pixels, 256 cores) e foi totalmente otimizado para ambientes DOS genuínos ou emuladores (como DOSBox).

---

## 🛠️ Como Compilar e Executar

### Pré-requisitos
Você precisará do **NASM** (Netwide Assembler) instalado na sua máquina (disponível nativamente no Linux Manjaro via `pacman -S nasm`).

### Compilação
Abra o terminal na pasta do projeto e execute o comando abaixo para gerar o executável compacto `.COM`:
```bash
nasm lfsr.asm -o lfsr.com
