module pulpino_memory_subsystem (
    input logic clk_i,
    input logic rst_ni,

    // Interface de Instrução (Vinda do Core)
    input  logic        insn_req_i,
    output logic        insn_gnt_o,
    input  logic [31:0] insn_addr_i,
    output logic        insn_rvalid_o,
    output logic [31:0] insn_rdata_o,

    // Interface de Dados (Vinda do Core)
    input  logic        data_req_i,
    output logic        data_gnt_o,
    input  logic [31:0] data_addr_i,
    input  logic        data_we_i,
    input  logic [ 3:0] data_be_i,
    input  logic [31:0] data_wdata_i,
    output logic        data_rvalid_o,
    output logic [31:0] data_rdata_o
);

    // Decodificação de Endereço (Mapa de Memória PULPino)
    logic sel_boot_rom;
    logic sel_iram;
    logic sel_dram;

    // Boot ROM 0x0008_0000
    assign sel_boot_rom = (insn_addr_i[31:16] == 16'h0008);
    // IRAM 0x0000_0000
    assign sel_iram     = (insn_addr_i[31:16] == 16'h0000);
    // DRAM 0x0010_0000 (Apenas dados acessam aqui neste exemplo simples)
    assign sel_dram     = (data_addr_i[31:16] == 16'h0010);

    logic        rom_gnt, iram_gnt;
    logic        rom_rvalid, iram_rvalid;
    logic [31:0] rom_rdata, iram_rdata;

    // 1. INSTÂNCIA DA BOOT ROM (512 Bytes)
    boot_rom_obi #(
        .ADDR_WIDTH(7) // 128 palavras = 512 bytes
    ) i_boot_rom (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),
        .req_i    (insn_req_i & sel_boot_rom), // Só ativa se endereço bater
        .gnt_o    (rom_gnt),
        .addr_i   (insn_addr_i),
        .rvalid_o (rom_rvalid),
        .rdata_o  (rom_rdata)
    );

    // 2. INSTÂNCIA DA INSTRUCTION RAM (32 KB)
    sp_ram_obi #(
        .ADDR_WIDTH(13) // 8K palavras = 32KB
    ) i_iram (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),
        .req_i    (insn_req_i & sel_iram),     // Só ativa se endereço bater
        .gnt_o    (iram_gnt),
        .addr_i   (insn_addr_i),
        .we_i     (1'b0),                      // Core não escreve na IRAM via barramento de instr.
        .be_i     (4'b0000),
        .wdata_i  (32'b0),
        .rvalid_o (iram_rvalid),
        .rdata_o  (iram_rdata)
    );

    // 3. INSTÂNCIA DA DATA RAM (32 KB)
    // A DRAM está conectada direto na porta de dados neste exemplo
    sp_ram_obi #(
        .ADDR_WIDTH(13) // 32KB
    ) i_dram (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),
        .req_i    (data_req_i),                // Assume que todo acesso de dados vai pra DRAM (simplificado)
        .gnt_o    (data_gnt_o),
        .addr_i   (data_addr_i),
        .we_i     (data_we_i),
        .be_i     (data_be_i),
        .wdata_i  (data_wdata_i),
        .rvalid_o (data_rvalid_o),
        .rdata_o  (data_rdata_o)
    );

    // MUX DE RESPOSTA DA INSTRUÇÃO (ROM vs IRAM)
    
    assign insn_gnt_o    = rom_gnt | iram_gnt;
    assign insn_rvalid_o = rom_rvalid | iram_rvalid;
    assign insn_rdata_o  = (rom_rvalid) ? rom_rdata : iram_rdata;

endmodule