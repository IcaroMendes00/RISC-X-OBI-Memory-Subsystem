module sp_ram_obi #(
    parameter ADDR_WIDTH = 14, // 16KB (2^14 = 16384 bytes)
    parameter DATA_WIDTH = 32
)(
    input  logic                   clk_i,
    input  logic                   rst_ni,
    
    // OBI
    input  logic                   req_i,
    output logic                   gnt_o,
    input  logic [31:0]            addr_i,
    input  logic                   we_i,
    input  logic [3:0]             be_i,
    input  logic [31:0]            wdata_i,
    output logic                   rvalid_o,
    output logic [31:0]            rdata_o
);

    logic [DATA_WIDTH-1:0] mem_array [0:(2**ADDR_WIDTH)-1];
    logic [ADDR_WIDTH-1:0] local_addr;

    assign local_addr = addr_i[ADDR_WIDTH+1:2];
    assign gnt_o = req_i; 

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rvalid_o <= 1'b0;
            rdata_o  <= '0;
        end else begin
            rvalid_o <= req_i;

            if (req_i) begin
                // Escrita com Byte Enable (Importante para DRAM)
                if (we_i) begin
                    if (be_i[0]) mem_array[local_addr][7:0]   <= wdata_i[7:0];
                    if (be_i[1]) mem_array[local_addr][15:8]  <= wdata_i[15:8];
                    if (be_i[2]) mem_array[local_addr][23:16] <= wdata_i[23:16];
                    if (be_i[3]) mem_array[local_addr][31:24] <= wdata_i[31:24];
                end 
                
                rdata_o <= mem_array[local_addr];
            end
        end
    end
    
    // Opcional: Inicializar memória com arquivo (para simulação)
    //initial begin
        // Descomente e aponte para seu arquivo .hex ou .slm
        // $readmemh("firmware.hex", mem_array); 
    //end

endmodule