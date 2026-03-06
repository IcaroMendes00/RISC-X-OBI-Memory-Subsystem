# gera_boot_hex.py
depth = 512  # 2**ADDR_WIDTH
filename = "boot_code.hex"

with open(filename, "w") as f:
    for i in range(depth):
        # Gera um dado onde o valor é o próprio índice para facilitar o rastreio
        # Exemplo: Endereço 0x00 contém 0x00000000, 0x01 contém 0x00000001...
        f.write(f"{i:08x}\n")

print(f"Arquivo {filename} gerado com sucesso!")