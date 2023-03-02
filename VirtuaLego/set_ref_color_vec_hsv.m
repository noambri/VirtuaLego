function ref_array = set_ref_color_vec_hsv()
    % The function calc the ref vector for each color - "red", "yellow", "white" and "blue"
    % The function gets an image with 4 cubes (one in each color) 
    % and a number of sample to take from the image for each color.
    % The function return an array in size 4*3 with 4 reference vectors.

    % --- Settings --------------------------------------------
    sample_num = 4;% Amount of samples per color
    
    colors_array = ["red","yellow","white","blue","black","ground_color"];
    amount_of_colors = length(colors_array);
    imgFromFileNames = ["calib_colors_top","calib_colors_left","calib_colors_right","calib_colors_back"];
    side_names = ["Top","Left","Right","Back"];
    
    % ---------------------------------------------------------

    % Load image
    for cam_idx = 1:4
        imgFromFileName = imgFromFileNames(cam_idx);
        side_name = side_names(cam_idx);
        img_path = fullfile("DemoImages","ImgFromFile",imgFromFileName+".bmp");
        if exist(img_path,"file")
            img = imread(img_path);
        else
            disp("Img from file not exist!");
        end
    
        img = double(img)./255;
        
        % Set a reference array
        ref_array = zeros([amount_of_colors 3]);
        
        % Set a sample array
        sample_array_rgb = zeros([sample_num, 3]);
        
        % Open a figure with the image to take the samples
        ginput_fig = figure;
        imshow(img);
    
        %
    
        
        
        % Calc the reference vectors
        for i=1:amount_of_colors % one ref vector for each color
           title(side_name+": "+colors_array(i)+" x "+num2str(sample_num)+" times");
           [img_x, img_y] = ginput(sample_num); % take sample from the image
           for sample = 1:sample_num % save thr rgb value from the selected points
               sample_array_rgb(sample,:) = img(round(img_y(sample)), round(img_x(sample)), :);
           end
           % Save the ref vec (the avrege of all the sapmled points)
           ref_array(i,:) = mean(sample_array_rgb);
        end

        switch cam_idx
            case 1
                top_ref_array = ref_array;
            case 2
                left_ref_array = ref_array;
            case 3
                right_ref_array = ref_array;
            case 4
                back_ref_array = ref_array;
        end
        
        close(ginput_fig); % close the figure;
    end

    % Save to *.mat file
    save("color_calib.mat","top_ref_array","left_ref_array","right_ref_array","back_ref_array");
    
end