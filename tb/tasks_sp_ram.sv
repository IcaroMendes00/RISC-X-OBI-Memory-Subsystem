// tasks_sp_ram.sv
// tasks para teste do sp_ram_obi.sv
// autor: Icaro M. de Alcantara
// 14-2-2026

// Task para resetar o sistema (SP RAM e sinais de controle)
task reset_system();
    $display("[T=%0t] Reset system init...", $time);
    req_i   = 0;
    addr_i  = 0;
    we_i    = 0;
    be_i    = 0;
    wdata_i = 0;
    rst_ni  = 0;
    repeat(2) @(posedge clk_i);
    rst_ni  = 1;
    @(posedge clk_i);
    $display("[T=%0t] Reset system finished!!!", $time);
endtask

// Task para escrever um dado na SP RAM via OBI
task obi_write(
    input logic [31:0] addr,
    input logic [31:0] data,
    input logic [ 3:0] byte_enable
);
    @(posedge clk_i);
    req_i   <= 1'b1;
    we_i    <= 1'b1;
    addr_i  <= addr;
    wdata_i <= data;
    be_i    <= byte_enable;

    // Aguarda o grant
    wait(gnt_o === 1'b1);
    
    @(posedge clk_i);
    req_i   <= 1'b0;
    we_i    <= 1'b0;
endtask

// Task para ler um dado da SP RAM via OBI e verificar o resultado
task obi_read_check(
    input logic [31:0] addr,
    input logic [31:0] expected_data,
    input logic [31:0] mask = 32'hFFFF_FFFF
);
    @(posedge clk_i);
    req_i  <= 1'b1;
    we_i   <= 1'b0;
    addr_i <= addr;

    wait(gnt_o === 1'b1);
    
    @(posedge clk_i); // Avanca para o ciclo da resposta
    req_i  <= 1'b0;   // Derruba o request
    #1;
    // Verifica a resposta
    if (rvalid_o !== 1'b1) begin
        $error("[ERRO T=%0t] rvalid_o nao subiu apos leitura no endereco %0h", $time, addr);
    end else if ((rdata_o & mask) !== (expected_data & mask)) begin
        $error("[ERRO T=%0t] Dado incorreto no endereco %0h. LIDO: %0h ESPERADO: %0h (Mascara: %0h)", $time, addr, rdata_o, expected_data, mask);
    end else begin
        $display("[OK T=%0t] Leitura correta no endereco %0h: %0h", $time, addr, rdata_o);
    end
endtask

// Task para testar o trafego Back-to-Back (Pipelining de 3 transacoes)
task obi_burst_write_read_check(
    input logic [31:0] addr1, input logic [31:0] data1,
    input logic [31:0] addr2, input logic [31:0] data2,
    input logic [31:0] addr3, input logic [31:0] data3
);
    $display("\n--- Iniciando Teste Back-to-Back (Escrita) ---");
    @(posedge clk_i);
    req_i <= 1'b1; 
    we_i  <= 1'b1; 
    be_i  <= 4'b1111;
    
    // 1. ESCRITA EM RAJADA
    addr_i <= addr1; wdata_i <= data1; @(posedge clk_i);
    addr_i <= addr2; wdata_i <= data2; @(posedge clk_i);
    addr_i <= addr3; wdata_i <= data3; @(posedge clk_i);        
    
    // 2. LEITURA EM RAJADA
    $display("\n--- Iniciando Leitura Back-to-Back (Pipelining) ---");
    we_i  <= 1'b0; 
    
    // Ciclo 1 de Leitura: Pede o endereco 1
    addr_i <= addr1; 
    @(posedge clk_i); 
    #1; // Atraso para ler o rvalid_o/rdata_o estabilizado
    
    // Ciclo 2 de Leitura: Pede o endereco 2 e checa o dado 1
    addr_i <= addr2;
    if (rvalid_o && rdata_o === data1) 
        $display("[OK T=%0t] Leitura Pipeline @%0h: %0h", $time, addr1, rdata_o);
    else 
        $error("[ERRO T=%0t] Falha Leitura Pipeline @%0h. LIDO: %0h | ESPERADO: %0h", $time, addr1, rdata_o, data1);
    
    @(posedge clk_i);
    #1;

    // Ciclo 3 de Leitura: Pede o endereco 3 e checa o dado 2
    addr_i <= addr3;
    if (rvalid_o && rdata_o === data2) 
        $display("[OK T=%0t] Leitura Pipeline @%0h: %0h", $time, addr2, rdata_o);
    else 
        $error("[ERRO T=%0t] Falha Leitura Pipeline @%0h. LIDO: %0h | ESPERADO: %0h", $time, addr2, rdata_o, data2);
        
    @(posedge clk_i);
    #1;
    
    // Ciclo 4: Encerra as requisicoes e checa o dado 3
    req_i <= 1'b0;
    if (rvalid_o && rdata_o === data3) 
        $display("[OK T=%0t] Leitura Pipeline @%0h: %0h", $time, addr3, rdata_o);
    else 
        $error("[ERRO T=%0t] Falha Leitura Pipeline @%0h. LIDO: %0h | ESPERADO: %0h", $time, addr3, rdata_o, data3);
    
    @(posedge clk_i); // Avanca mais um ciclo para limpar a tela do waveform
endtask

// Task para testar a Escrita Nula (Zero Byte-Enable)
task obi_test_zero_byte_enable(
    input logic [31:0] addr,
    input logic [31:0] safe_data,
    input logic [31:0] dirty_data
);
    $display("\n--- Iniciando Teste de Escrita Nula (Zero Byte-Enable) @%0h ---", addr);
    
    // Passo A: Escreve o dado seguro com todos os bytes habilitados (be_i = 1111)
    obi_write(addr, safe_data, 4'b1111);
    
    // Passo B: Tenta sobrescrever com dado sujo, mas com mascara zerada (be_i = 0000)
    obi_write(addr, dirty_data, 4'b0000);
    
    // Passo C: Verifica se o dado seguro foi mantido perfeitamente intacto
    obi_read_check(addr, safe_data);
endtask

// Task para testar Endereçamento Desalinhado (Unaligned Aliasing)
task obi_test_unaligned_aliasing(
    input logic [31:0] base_addr,
    input logic [31:0] test_data
);
    $display("\n--- Iniciando Teste de Enderecamento Desalinhado @%0h ---", base_addr);
    
    // Passo 1: Escreve a palavra completa no endereco alinhado base
    obi_write(base_addr, test_data, 4'b1111);
    
    // Passo 2: Lê nos endereços com offset de bytes. 
    // A memoria deve ignorar os 2 LSBs e retornar a mesma palavra sempre.
    obi_read_check(base_addr + 32'h1, test_data);
    obi_read_check(base_addr + 32'h2, test_data);
    obi_read_check(base_addr + 32'h3, test_data);
endtask


// Task para testar Tráfego Intercalado Robusto (Stress Test W-R-W-R cruzado)
task obi_test_robust_interleaved(
    input logic [31:0] a1, input logic [31:0] d1,
    input logic [31:0] a2, input logic [31:0] d2,
    input logic [31:0] a3, input logic [31:0] d3,
    input logic [31:0] a4, input logic [31:0] d4
);
    $display("\n--- Iniciando Tráfego Intercalado Robusto (Stress Test) ---");

    // Passo 0: Pré-grava o Endereço 1 isoladamente
    obi_write(a1, d1, 4'b1111);
    
    // === INÍCIO DA RAJADA ININTERRUPTA ===
    
    // Ciclo 1: Injeta Escrita A2
    @(posedge clk_i);
    req_i   <= 1'b1; 
    we_i    <= 1'b1; 
    be_i    <= 4'b1111;
    addr_i  <= a2; 
    wdata_i <= d2;

    // Ciclo 2: Injeta Leitura A1
    @(posedge clk_i);
    we_i    <= 1'b0; 
    addr_i  <= a1;

    // Ciclo 3: Injeta Escrita A3 e CHECA Leitura A1
    @(posedge clk_i);
    we_i    <= 1'b1; 
    addr_i  <= a3; 
    wdata_i <= d3;
    
    #1; // Checa o que acabou de aparecer (Resposta da Leitura A1)
    if (rvalid_o && rdata_o === d1) $display("[OK T=%0t] LIDO A1 @%0h: %0h", $time, a1, rdata_o);
    else $error("[ERRO T=%0t] Falha Leitura A1 @%0h. Esperado: %0h, Lido: %0h", $time, a1, d1, rdata_o);

    // Ciclo 4: Injeta Leitura A2
    @(posedge clk_i);
    we_i    <= 1'b0; 
    addr_i  <= a2;
    // (A resposta da Escrita A3 está no barramento agora, ignoramos)

    // Ciclo 5: Injeta Escrita A4 e CHECA Leitura A2
    @(posedge clk_i);
    we_i    <= 1'b1; 
    addr_i  <= a4; 
    wdata_i <= d4;
    
    #1; // Checa o que acabou de aparecer (Resposta da Leitura A2)
    if (rvalid_o && rdata_o === d2) $display("[OK T=%0t] LIDO A2 @%0h: %0h", $time, a2, rdata_o);
    else $error("[ERRO T=%0t] Falha Leitura A2 @%0h. Esperado: %0h, Lido: %0h", $time, a2, d2, rdata_o);

    // Ciclo 6: Injeta Leitura A3
    @(posedge clk_i);
    we_i    <= 1'b0; 
    addr_i  <= a3;
    // (A resposta da Escrita A4 está no barramento agora, ignoramos)

    // Ciclo 7: Injeta Leitura A4 e CHECA Leitura A3
    @(posedge clk_i);
    we_i    <= 1'b0; 
    addr_i  <= a4;
    
    #1; // Checa o que acabou de aparecer (Resposta da Leitura A3)
    if (rvalid_o && rdata_o === d3) $display("[OK T=%0t] LIDO A3 @%0h: %0h", $time, a3, rdata_o);
    else $error("[ERRO T=%0t] Falha Leitura A3 @%0h. Esperado: %0h, Lido: %0h", $time, a3, d3, rdata_o);

    // Ciclo 8: Encerra o tráfego e CHECA Leitura A4
    @(posedge clk_i);
    req_i   <= 1'b0; 
    
    #1; // Checa o que acabou de aparecer (Resposta da Leitura A4)
    if (rvalid_o && rdata_o === d4) $display("[OK T=%0t] LIDO A4 @%0h: %0h", $time, a4, rdata_o);
    else $error("[ERRO T=%0t] Falha Leitura A4 @%0h. Esperado: %0h, Lido: %0h", $time, a4, d4, rdata_o);
    
    @(posedge clk_i); // Limpa o waveform
endtask

// Task para testar os Limites da Memoria (Boundary Access)
task obi_test_boundary_access(
    input logic [31:0] first_addr, input logic [31:0] first_data,
    input logic [31:0] last_addr,  input logic [31:0] last_data
);
    $display("\n--- Iniciando Teste de Limites da Memoria (Boundary Access) ---");
    
    // Passo 1: Escreve no PRIMEIRO endereco fisico
    $display("[INFO] Escrevendo no limite INFERIOR: %0h", first_addr);
    obi_write(first_addr, first_data, 4'b1111);
    
    // Passo 2: Escreve no ULTIMO endereco fisico
    $display("[INFO] Escrevendo no limite SUPERIOR: %0h", last_addr);
    obi_write(last_addr, last_data, 4'b1111);
    
    // Passo 3: Verifica se o primeiro dado continua la (Nao houve wrap-around)
    $display("[INFO] Verificando limite INFERIOR...");
    obi_read_check(first_addr, first_data);
    
    // Passo 4: Verifica se o ultimo dado foi gravado corretamente (Nao houve out-of-bounds)
    $display("[INFO] Verificando limite SUPERIOR...");
    obi_read_check(last_addr, last_data);
endtask
