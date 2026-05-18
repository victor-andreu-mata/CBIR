% Demo m-script for reading input.txt file and write output.txt files

% Data variables
User_root      = '/Users/pau.diport.i/Documents/MATLAB/PIV/PROG';
Data_root      = '/database/';
Input_filename = 'input.txt';
Output_filename= 'output.txt';
Candidates     = 10;  % Number of candidates to retrieve

Input = textread([User_root, Data_root, Input_filename],'%s');

% Get the Number of images to be Queried
Num_images = length(Input); 

% Open output file for writing the results
a=fopen([User_root, Data_root, Output_filename],'w'); 

for i=1:Num_images
    
    fprintf(a,'Retrieved list for query image %s \n',char(Input(i)));
    
    % Here, is suposed that the system gets a index vector to the most similar
    % images in the vector Similar_images;
    Similar_images = (1:Candidates);

    % Writing the results at the Output file
    for j=1:Candidates
        fprintf(a,'%s\n',sprintf('ukbench%05d.jpg',Similar_images(j)-1));
    end
    fprintf(a,'\n');
end

