module tb_inference();
reg clk,rst;

parameter m = 2;
parameter k = 3; 
parameter n = 4;
parameter bits = 3;
parameter multi_bits = 5;

reg [bits - 1:0] w[1:m][1:k] ;
reg [bits - 1:0] x[1:k][1:n] ;
parameter num_cyc = m-1 + n-1 + k;

integer i, j, r;

reg [bits*m - 1:0] row;
reg [bits*n - 1:0] column;
wire [m*n*multi_bits - 1:0] out;

Systolic_Array #(bits, m, n, multi_bits) sys_arr(clk, rst, row, column, out);
initial begin 
	w[1][1] = 1; w[1][2] = 1; w[1][3] = 0; 
	w[2][1] = 2; w[2][2] = 3; w[2][3] = 1; 

	
	x[1][1] = 6; x[1][2] = 0; x[1][3] = 3; x[1][4] = 4;
	x[2][1] = 5; x[2][2] = 0; x[2][3] = 1; x[2][4] = 0;
	x[3][1] = 1; x[3][2] = 2; x[3][3] = 1; x[3][4] = 3;
	

end

always begin
	clk = 0; #5;
	clk = 1; #5;
end

initial begin
   rst = 1; #1;
	rst = 0; 
	for(i = 1; i < num_cyc+1 ; i = i + 1) begin
		for(j = 1; j<m+1; j = j+1) begin
			if (i < j+k & i > j-1) begin
				row[bits*j - 1 -: bits] = w[j][i-(j-1)];
			end
			else begin
				row[bits*j - 1 -: bits] = 0;
			end
		
		end
		
		for(r = 1; r<n+1; r = r+1) begin
			if (i < r+k & i > r-1) begin
				column[bits*r - 1 -: bits] = x[i-(r-1)][r];
			end
			else begin
				column[bits*r - 1 -: bits] = 0;
			end
		
		end
		#10;
	
	end
 
 end
	
endmodule
	

