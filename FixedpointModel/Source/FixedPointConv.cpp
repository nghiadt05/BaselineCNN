// FixedPointConv.cpp : Defines the entry point for the console application.
//

#include <stdio.h>
#include <assert.h>
#include <time.h>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>

#define clip(n, min, max) if (n<min) n = min; else if(n>max) n = max;

using namespace std;

int main() {
	// Convolutional parameters
	const unsigned int conv_layer = 3;	// Number of convolutional layers
	vector<unsigned int> s = { 1, 1, 1 };	// Stride length

	// Input activations parameters
	unsigned int C_in = 3;		// Input activations channel size
	unsigned int W_in = 32;		// Input activations width
	unsigned int H_in = 32;		// Input activations height
	unsigned int InputSize = C_in * W_in * H_in;

	// Filter parameters
	unsigned int C_out = 16;	// Number of filters, hence output size (constant)
	unsigned int W_f = 3;		// Filter width (constant)
	unsigned int H_f = 3;		// Filter height (constant)
	unsigned int FilterSize = C_out * C_in * W_f * H_f;

	// Output activation parameters
	unsigned int W_out = (unsigned int)floor((W_in - W_f) / s[0]) + 1;
	unsigned int H_out = (unsigned int)floor((H_in - H_f) / s[0]) + 1;
	unsigned int OutputSize = C_out * W_out * H_out;

	// Maxpooling parameters
	const unsigned int p = 2;
	unsigned int W_p_out = (unsigned int)floor((W_out - p) / p) + 1;
	unsigned int H_p_out = (unsigned int)floor((H_out - p) / p) + 1;

	// Input, weight and ouput values
	vector<vector<float>> I(conv_layer);
	vector<vector<float>> W(conv_layer);
	vector<vector<float>> O(conv_layer);
	vector<vector<float>> OP(conv_layer);

	vector<vector<int>> II(conv_layer);
	vector<vector<int>> WW(conv_layer);
	vector<vector<int>> OO(conv_layer);
	vector<vector<int>> BB(conv_layer);
	vector<vector<int>> OOP(conv_layer);

	// Fixed-point model paramters
	unsigned int n = 3;
	unsigned int m = 4;
	unsigned int q = n + m;
	unsigned int _2_pow_m_ = 1 << m;
	signed int MAX = (1 << q) - 1;
	signed int MIN = -(1 << q);

	// Read the first input image from batch 1 (first 3073 byets)
	ifstream file("../../../Bin/testImage.bin", ios::in | ios::binary);
	char buffer[3073];
	file.read(buffer, 3073);
	file.close();

	// Initialize the first input activations 	
	for (unsigned int i = 0; i < InputSize; i++) {
		I[0].push_back((float)((unsigned char)buffer[i + 1]) / 255.0f);
		static int tmpI = 0;
		tmpI = (int)(floor((float)_2_pow_m_*(float)((unsigned char)buffer[i + 1]) / 255.0f));
		clip(tmpI, MIN, MAX);
		II[0].push_back(tmpI);
	}

	// Initialize filter values
	for (unsigned int i = 0; i < conv_layer; i++) {
		static char fileName[50];
		static unsigned int lines;
		static float w;
		static int ww;
		sprintf_s(fileName, "../../../Bin/w_conv_f_%d.txt", i);
		ifstream wfile(fileName, ios::in);
		_ASSERT(wfile);
		while (wfile >> w) {
			ww = (int)(floor(w*_2_pow_m_));
			clip(ww, MIN, MAX);
			W[i].push_back(w);
			WW[i].push_back(ww);
		}
	}

	// Offset addresses
	unsigned int WiHi = W_in*H_in;
	unsigned int WfHf = W_f*H_f;
	unsigned int WoHo = W_out*H_out;
	unsigned int CinWfHf = C_in*W_f*H_f;

	// Init the random seed
	srand(time(NULL));

	// Convolution 
	for (unsigned int i = 0; i < conv_layer; i++) {
		// update convolutional parameters for the new layer
		if (i > 0) {
			// input activation parameters
			C_in = C_out;
			H_in = H_p_out;
			W_in = W_p_out;
			InputSize = C_in * W_in * H_in;

			// filter paramets (constants)
			C_out = 16;
			H_f = 3;
			W_f = 3;
			FilterSize = C_out * C_in * W_f * H_f;

			// output activation parameters
			H_out = (unsigned int)floor((H_in - H_f) / s[i]) + 1;
			W_out = (unsigned int)floor((W_in - W_f) / s[i]) + 1;
			OutputSize = C_out * W_out * H_out;

			// max pooling parameters			
			H_p_out = (unsigned int)floor((H_out - p) / 2) + 1;
			W_p_out = (unsigned int)floor((W_out - p) / 2) + 1;

			// update offset address
			WiHi = W_in*H_in;
			WfHf = W_f*H_f;
			WoHo = W_out*H_out;
			CinWfHf = C_in*W_f*H_f;

			// Load input activations
			I[i] = OP[i - 1];
			II[i] = OOP[i - 1];
		}

		// convolutional computation
		for (unsigned int c_out_i = 0; c_out_i < C_out; c_out_i++) {
			vector<float> tmp_pool_f;
			vector<int> tmp_pool_i;
			// 3D convolutional computation 
			for (unsigned int h_out_i = 0; h_out_i < H_out; h_out_i++) {
				for (unsigned int w_out_i = 0; w_out_i < W_out; w_out_i++) {
					float tmpO = 0.0f;
					int tmpOOO = 0;
					for (unsigned int c_in_i = 0; c_in_i < C_in;c_in_i++) {
						int tmpOO = 0;
						for (unsigned int h_f_i = 0; h_f_i < H_f; h_f_i++) {
							for (unsigned int w_f_i = 0; w_f_i < W_f; w_f_i++) {
								float tmpI = 0.0f;
								float tmpW = 0.0f;
								int tmpII = 0;
								int tmpWW = 0;
								tmpW = W[i][c_out_i*CinWfHf + c_in_i*WfHf + h_f_i*W_f + w_f_i];
								tmpI = I[i][c_in_i*WiHi + (s[i] * h_out_i + h_f_i)*W_in + (s[i] * w_out_i + w_f_i)];
								tmpWW = WW[i][c_out_i*CinWfHf + c_in_i*WfHf + h_f_i*W_f + w_f_i];
								tmpII = II[i][c_in_i*WiHi + (s[i] * h_out_i + h_f_i)*W_in + (s[i] * w_out_i + w_f_i)];
								tmpO += tmpW*tmpI;
								tmpOO += tmpII*tmpWW;
							}
						}
						tmpOO = tmpOO >> m;
						clip(tmpOO, MIN, MAX); // MAC output						
						tmpOOO += tmpOO; //psum						
					}
					// add bias to psum
					int rand_bias = (int)(rand() % 10) - 5;
					BB[i].push_back(rand_bias);
					tmpOOO += rand_bias;
					clip(tmpOOO, MIN, MAX); // psum output

					tmpO += (float)rand_bias / (float)(1 << m);			
					O[i].push_back(tmpO);
					OO[i].push_back(tmpOOO);

					tmp_pool_f.push_back(tmpO);
					tmp_pool_i.push_back(tmpOOO);
				}
			}
			// end of 3D convolutional computation 

			// max pooling and relu
			for (unsigned int h_p_out_i = 0; h_p_out_i < H_p_out; h_p_out_i++) {
				for (unsigned int w_p_out_i = 0; w_p_out_i < W_p_out; w_p_out_i++) {
					float tmpMaxf = 0.0f;
					int tmpMaxi = 0;
					for (unsigned int i = 0; i < p; i++) {
						for (unsigned int j = 0; j < p; j++) {
							float tmpO = tmp_pool_f[(p*h_p_out_i + i)*W_out + (p*w_p_out_i + j)];
							int tmpOO = tmp_pool_i[(p*h_p_out_i + i)*W_out + (p*w_p_out_i + j)];
							if (tmpO > tmpMaxf)
								tmpMaxf = tmpO;
							if (tmpOO > tmpMaxi)
								tmpMaxi = tmpOO;
						}
					}
					OP[i].push_back(tmpMaxf);
					OOP[i].push_back(tmpMaxi);
				}
			}
		}
	}

	// print results to files
	for (unsigned int i = 0; i < conv_layer; i++) {
		static char ini[50], outi[50], wi[50], bi[50];
		sprintf(ini, "../../../../HWImplementation/Bin/i_conv_i_%d.txt", i);
		sprintf(wi, "../../../../HWImplementation/Bin/w_conv_i_%d.txt", i);
		sprintf(outi, "../../../../HWImplementation/Bin/o_conv_i_%d.txt", i);
		sprintf(bi, "../../../../HWImplementation/Bin/b_conv_i_%d.txt", i);
		ofstream file_ini, file_outi, file_wi, file_bi;

		// integer input activations				
		file_ini.open(ini);
		for (unsigned int j = 0; j < II[i].size(); j++) {
			file_ini << II[i][j] << endl;
		}
		file_ini.close();

		// integer weights
		file_wi.open(wi);
		for (unsigned int j = 0; j < WW[i].size(); j++) {
			file_wi << WW[i][j] << endl;
		}
		file_wi.close();

		// integer outputs
		file_outi.open(outi);
		for (unsigned int j = 0; j < OO[i].size(); j++) {
			file_outi << OO[i][j] << endl;
		}
		file_outi.close();

		// integer bias
		file_bi.open(bi);
		for (unsigned int j = 0; j < BB[i].size(); j++) {
			file_bi << BB[i][j] << endl;
		}
		file_bi.close();
	}
	return 0;
}
