module boot_rom_obi #(
    parameter ADDR_WIDTH = 9, // 512 Bytes (PULPino)
    parameter INIT_FILE  = "boot_code.hex"
)(
    input  logic                   clk_i,
    input  logic                   rst_ni,
    input  logic                   req_i,
    output logic                   gnt_o,
    input  logic [31:0]            addr_i,
    output logic                   rvalid_o,
    output logic [31:0]            rdata_o
);

    logic [31:0] mem_array [0:(2**ADDR_WIDTH)-1];
    logic [ADDR_WIDTH-1:0] local_addr;

    assign local_addr = addr_i[ADDR_WIDTH+1:2];
    assign gnt_o      = req_i;

    // Carrega o firmware na simulacao
    initial begin
        $readmemh(INIT_FILE, mem_array);
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rvalid_o <= 1'b0;
            rdata_o  <= '0;
        end else begin
            rvalid_o <= req_i;
            if (req_i) begin
                rdata_o <= mem_array[local_addr];
            end
        end
    end
endmodule