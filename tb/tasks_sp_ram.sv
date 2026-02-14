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
    
    // Verifica a resposta
    if (rvalid_o !== 1'b1) begin
        $error("[ERRO T=%0t] rvalid_o nao subiu apos leitura no endereco %0h", $time, addr);
    end else if ((rdata_o & mask) !== (expected_data & mask)) begin
        $error("[ERRO T=%0t] Dado incorreto no endereco %0h. LIDO: %0h ESPERADO: %0h (Mascara: %0h)", $time, addr, rdata_o, expected_data, mask);
    end else begin
        $display("[OK T=%0t] Leitura correta no endereco %0h: %0h", $time, addr, rdata_o);
    end
endtask