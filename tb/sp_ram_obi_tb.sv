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

    // debug
    logic [31:0]            debug_mem;

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
        .rdata_o  (rdata_o),
        .debug_mem(debug_mem) 
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
        // Passando os 3 enderecos e os 3 dados esperados
        obi_burst_write_read_check(
            32'h0000_3000, 32'h11111111,
            32'h0000_3004, 32'h22222222,
            32'h0000_3008, 32'h33333333
        );

	// Step 5: Teste de Escrita Nula (Zero Byte-Enable)
        // Tentaremos gravar 0xFFFFFFFF no endereco 4000, mas com be_i = 0
        obi_test_zero_byte_enable(32'h0000_4000, 32'h11223344, 32'hFFFFFFFF);
	
	// Step 6: Teste de Enderecamento Desalinhado (Unaligned Aliasing)
        // O endereco base e 0x4000. A task vai testar o 4001, 4002 e 4003 automaticamente.
        obi_test_unaligned_aliasing(32'h0000_4000, 32'hAABBCCDD);

	// Step 7: Tráfego Intercalado Robusto (Stress Test)
        // Simulando o comportamento aleatório da Load/Store Unit de um RISC-V real
        obi_test_robust_interleaved(
            32'h0000_6000, 32'h0000_1111, // A1, D1
            32'h0000_6004, 32'h0000_2222, // A2, D2
            32'h0000_6008, 32'h0000_3333, // A3, D3
            32'h0000_600C, 32'h0000_4444  // A4, D4
        );;

	// Step 8: Teste de Limites da Memoria (Boundary Access)
        // Primeiro endereco: 0x0000_0000 | Ultimo endereco: 0x0000_FFFC
        obi_test_boundary_access(
            32'h0000_0000, 32'h1111_1111, // Limite Inferior
            32'h0000_FFFC, 32'h9999_9999  // Limite Superior
        );
	
        @(posedge clk_i);
        $display("\n[T=%0t] --- VERIFICACAO CONCLUIDA COM SUCESSO ---", $time);
        $finish;
    end

endmodule
