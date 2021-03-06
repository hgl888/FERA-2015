function [ success ] = write_geom_lin_dyn_svr( location, means, scaling, w, b)
%WRITE_LIN_SVR Summary of this function goes here
%   Detailed explanation goes here

    fileID = fopen(location, 'w');

    if(fileID ~= -1)
        
        % Write the regressor type 2 - linear dynamic geometry SVR
        fwrite(fileID, 2, 'uint');
        
        writeMatrixBin(fileID, means, 6);
        writeMatrixBin(fileID, scaling, 6);
        writeMatrixBin(fileID, w, 6);
        fwrite(fileID, b, 'float64');
                
        fclose(fileID);
        
        success = true;
        
    else
        success = false; 
    end
    
end

