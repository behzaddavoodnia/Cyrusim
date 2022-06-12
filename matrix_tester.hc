#heracles (Cyrusim)

//Authour: Behzad Davoodnia
// Core #4 is mother and Cores 6, 8, 10 are workers.
// General variable types

// Shared and general functions
void matrix_add (int Arr[4][4], int Arr0[4][4], int Arr1[4][4], int col) {
	int i; 
	for (i= 0; i< 4; i++) 
	    Arr[i][col] =  Arr0[i][col] +  Arr1[i][col]; 
}
//test functions------------------
void func (int Tester_Arr[16], int core_ID){
Tester_Arr[core_ID]=core_ID+100;
}
//--------------------------------
#pragma Heracles core 4 { 
	// Synchronizers
    HLock    lock1;
	
	HBarrier bar1, bar2, bar3, bar0, bar5, bar6, bar7, bar8, bar9, bar10, bar11, bar12, bar13, bar14, bar15; 

	// Variables 
	HGlobal int arg1, arg2, arg3; 

	
	HGlobal int Arr[4][4]; 
	HGlobal int Arr0[4][4] = { { 10, 11, 12, 13}, {10, 11, 12, 13}, {10, 11, 12, 13 }, {10, 11, 12, 13}};
	HGlobal int Arr1[4][4] = { { 14, 15, 16, 17}, { 14, 15, 16, 17}, { 14, 15, 16, 17}, { 14, 15, 16, 17}};
    
	HGlobal int Tester_Arr[16];
	
	// Workers
        #pragma Heracles core 1 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 
          
	    	func ( Tester_Arr, 1);
	    	
			clear_barrier(&bar1); 
        }

        #pragma Heracles core 2 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 
            
	        func ( Tester_Arr, 2);
	   	 	clear_barrier(&bar2); 
        }

        #pragma Heracles core 3 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 

            func ( Tester_Arr, 3);
	    	clear_barrier(&bar3); 
        
		} 
          #pragma Heracles core 0 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 
          
		   
             func ( Tester_Arr, 0);
	    	 
	    	clear_barrier(&bar0); 
        }

	  #pragma Heracles core 5 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 

	    	func ( Tester_Arr, 5);
	    	clear_barrier(&bar5); 
        }

		 #pragma Heracles core 6 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 
            
		    func ( Tester_Arr, 6);
			matrix_add(Arr, Arr0, Arr1, arg1); 	 
	    	
	    	clear_barrier(&bar6); 
        }

		 #pragma Heracles core 7 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 

	    	func ( Tester_Arr, 7);
	    	clear_barrier(&bar7); 
        

		}
              #pragma Heracles core 8 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 
            func ( Tester_Arr, 8);
	    	matrix_add(Arr, Arr0, Arr1, arg2); 
	    	clear_barrier(&bar8); 
        }

		 #pragma Heracles core 9 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 
             
	    	 func ( Tester_Arr, 9);
	    	clear_barrier(&bar9); 
        }

		 #pragma Heracles core 10 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 
             func ( Tester_Arr, 10);
	    	 matrix_add(Arr, Arr0, Arr1, arg3);
	    	clear_barrier(&bar10); 
        }

		 #pragma Heracles core 11 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 

	    	func ( Tester_Arr, 11);
	    	clear_barrier(&bar11); 
        }

		 #pragma Heracles core 12 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 

	    	func ( Tester_Arr, 12);
	    	clear_barrier(&bar12); 
        }

		 #pragma Heracles core 13 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 

	    	func ( Tester_Arr, 13);
	    	clear_barrier(&bar13); 
        }

		 #pragma Heracles core 14 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 

	    	func ( Tester_Arr, 14);
	    	clear_barrier(&bar14); 
        }

		 #pragma Heracles core 15 { 
            start_check(50); 
	    	check_lock(&lock1, 0, 100); 
             func ( Tester_Arr, 15);
	    	clear_barrier(&bar15); 
        }


	// Main function 
	int main(void){
    	locking(&lock1, 0);
		start();        // this block all other cores from starting

		arg1 = 1; 
    	arg2 = 3;
    	arg3 = 2;

		release(&lock1, 0);

		set_barrier(&bar1, 1); 
		set_barrier(&bar2, 1); 
		set_barrier(&bar3, 1); 
        set_barrier(&bar0, 1); 
		set_barrier(&bar5, 1); 
		set_barrier(&bar6, 1); 
        set_barrier(&bar7, 1); 
		set_barrier(&bar8, 1); 
		set_barrier(&bar9, 1); 
        set_barrier(&bar10, 1); 
		set_barrier(&bar11, 1); 
		set_barrier(&bar12, 1); 
        set_barrier(&bar13, 1); 
		set_barrier(&bar14, 1); 
		set_barrier(&bar15, 1); 
        
		func ( Tester_Arr, 4);
		matrix_add(Arr, Arr0, Arr1, 0); 

		check_barrier(&bar1, 100); 
		check_barrier(&bar2, 100);
		check_barrier(&bar3, 100);
        check_barrier(&bar0, 100); 
		check_barrier(&bar5, 100);
		check_barrier(&bar6, 100);
        check_barrier(&bar7, 100); 
		check_barrier(&bar8, 100);
		check_barrier(&bar9, 100);
        check_barrier(&bar10, 100); 
		check_barrier(&bar11, 100);
		check_barrier(&bar12, 100);
        check_barrier(&bar13, 100); 
		check_barrier(&bar14, 100);
		check_barrier(&bar15, 100);

		int i, j, k; 
		for (i= 0; i< 4; i++)
			for (j= 0; j< 4; j++)
				h_print(Arr[i][j]);
				
		  for (k=0; k< 16; k++) 
               h_print(Tester_Arr[k]);		

    	return 0; 
	}
}
