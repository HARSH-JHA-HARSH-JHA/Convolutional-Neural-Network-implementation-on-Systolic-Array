module tb_brute_inference();

reg clk,rst;
reg [5:0] row;
reg [11:0] column;
wire [39:0] out;

Systolic_Array #(3, 2, 4, 5) sa(clk,rst,row,column,out);

always begin
clk=0;#5;
clk=1;#5;
end

initial begin
rst=1;row=0;column=0;#1;
rst=0;#13;
row=6'b000_001;column=12'b000_000_000_110;#10;
row=6'b010_001;column=12'b000_000_000_101;#10;
row=6'b011_000;column=12'b000_011_000_001;#10;
row=6'b001_000;column=12'b100_001_010_000;#10;
row=6'b000_000;column=12'b000_001_000_000;#10;
row=6'b000_000;column=12'b011_000_000_000;#10;
row=6'b000_000;column=12'b000_000_000_000;#10;

end

endmodule