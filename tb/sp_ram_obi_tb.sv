`timescale 1ns/1ps

module tb_sp_ram_obi();

    localparam ADDR_WIDTH = 14;
    localparam DATA_WIDTH = 32;

    logic                   clk_i;
    logic                   rst_ni;
    
    // Interface OBI
    logic                   req_i;
    logic                   gnt_o;
    logic [31:0]            addr_i;
    logic                   we_i;
    logic [3:0]             be_i;
    logic [31:0]            wdata_i;
    logic                   rvalid_o;
    logic [31:0]            rdata_o;

    `include "tasks_sp_ram.sv"

    // DUT
    sp_ram_obi #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),
        .req_i    (req_i),
        .gnt_o    (gnt_o),
        .addr_i   (addr_i),
        .we_i     (we_i),
        .be_i     (be_i),
        .wdata_i  (wdata_i),
        .rvalid_o (rvalid_o),
        .rdata_o  (rdata_o)
    );

    // Clock Generation
    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;
    end

    // Test Sequence
    initial begin
        // Step 1: Reset do Sistema
        reset_system();

        // Step 2: Teste de acesso basico (Alinhado)
        $display("\n--- Iniciando Teste de Acesso Basico ---");
        obi_write(32'h0000_1000, 32'hDEADBEEF, 4'b1111);
        obi_read_check(32'h0000_1000, 32'hDEADBEEF);

        obi_write(32'h0000_1004, 32'hCAFEBA00, 4'b1111);
        obi_read_check(32'h0000_1004, 32'hCAFEBA00);

        // Step 3: Teste de granularidade (Byte-Enables)
        // Teste p/ DRAM real
        $display("\n--- Iniciando Teste de Byte-Enables ---");
        obi_write(32'h0000_2000, 32'h00000000, 4'b1111); // A) Escreve zero no endereço base para limpar a palavra
        obi_write(32'h0000_2000, 32'hFFFFFFAA, 4'b0001); // B) Escreve 0xAA apenas no byte 0 (bits 7:0)
        obi_write(32'h0000_2000, 32'hFFBBFFFF, 4'b0100); // C) Escreve 0xBB apenas no byte 2 (bits 23:16)

        obi_read_check(32'h0000_2000, 32'h00BB00AA);     // D) Le a palavra inteira e verifica se os bytes 1 e 3 continuam em zero
        // Resultado esperado: 0x00(byte3) BB(byte2) 00(byte1) AA(byte0)

        // Step 4: Trafego Back-to-Back (Pipelining sem wait-states)
        $display("\n--- Iniciando Teste Back-to-Back (Escrita) ---");
        @(posedge clk_i);
        req_i <= 1'b1; 
        we_i  <= 1'b1; 
        be_i  <= 4'b1111;
        
        // 3 ciclos seguidos escrevendo sem baixar o req_i
        addr_i <= 32'h0000_3000; wdata_i <= 32'h11111111; @(posedge clk_i);
        addr_i <= 32'h0000_3004; wdata_i <= 32'h22222222; @(posedge clk_i);
        addr_i <= 32'h0000_3008; wdata_i <= 32'h33333333; @(posedge clk_i);
        req_i  <= 1'b0; 
        we_i   <= 1'b0;
        
        $display("\n--- Verificando Teste Back-to-Back ---");
        obi_read_check(32'h0000_3000, 32'h11111111);
        obi_read_check(32'h0000_3004, 32'h22222222);
        obi_read_check(32'h0000_3008, 32'h33333333);

        $display("\n[T=%0t] --- VERIFICACAO CONCLUIDA COM SUCESSO ---", $time);
        $finish;
    end

endmodule