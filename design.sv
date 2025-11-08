// --------------------
// Simple 4x4 NoC (Verilog)
// Payload: 2 bits
// Destination-based routing
// --------------------
module noc_4x4 (
    input  [1:0] src_x, src_y,       // source coordinates
    input  [1:0] dest_x, dest_y,     // destination coordinates
    input  [1:0] payload,            // 2-bit message
    output reg [1:0] out00, out01, out02, out03,
    output reg [1:0] out10, out11, out12, out13,
    output reg [1:0] out20, out21, out22, out23,
    output reg [1:0] out30, out31, out32, out33
);

    // Clear all outputs every time input changes
    always @(*) begin
        out00 = 2'b00; out01 = 2'b00; out02 = 2'b00; out03 = 2'b00;
        out10 = 2'b00; out11 = 2'b00; out12 = 2'b00; out13 = 2'b00;
        out20 = 2'b00; out21 = 2'b00; out22 = 2'b00; out23 = 2'b00;
        out30 = 2'b00; out31 = 2'b00; out32 = 2'b00; out33 = 2'b00;

        // Route payload directly based on destination coordinates
        case ({dest_x, dest_y})
            4'b0000: out00 = payload; // (0,0)
            4'b0001: out01 = payload; // (0,1)
            4'b0010: out02 = payload; // (0,2)
            4'b0011: out03 = payload; // (0,3)

            4'b0100: out10 = payload; // (1,0)
            4'b0101: out11 = payload;
            4'b0110: out12 = payload;
            4'b0111: out13 = payload;

            4'b1000: out20 = payload;
            4'b1001: out21 = payload;
            4'b1010: out22 = payload;
            4'b1011: out23 = payload;

            4'b1100: out30 = payload;
            4'b1101: out31 = payload;
            4'b1110: out32 = payload;
            4'b1111: out33 = payload;

            default: ; // ignore invalid destination
        endcase
    end
endmodule

