function ref_array = set_ref_color_vec()
    % The function calc the ref vector for each color - "red", "yellow", "white" and "blue"
    % The function gets an image with 4 cubes (one in each color) 
    % and a number of sample to take from the image for each color.
    % The function return an array in size 4*3 with 4 reference vectors.

    global isImgFromFile
    global cam_top cam_left cam_right cam_back cam_demo
    camera_objects = [cam_top,cam_left,cam_right,cam_back];

    % --- Settings --------------------------------------------
    sample_num = 4;% Amount of samples per color
    
    colors_array = ["red","yellow","white","blue","ground_color"];
    amount_of_colors = length(colors_array);
    file_idx = input("file index (top_cam_x)? ");
    folder_name = input("folder name?");
    imgFromFileNames = ["cam_top_"+file_idx,"cam_left_"+file_idx,"cam_right_"+file_idx,"cam_back_"+file_idx];
    side_names = ["Top","Left","Right","Back"];

    %load("color_calib.mat","top_ref_array","left_ref_array","right_ref_array","back_ref_array");
    
    % ---------------------------------------------------------

    % Load image
    for cam_idx = 1:4
        side_name = side_names(cam_idx);
        if isImgFromFile
            imgFromFileName = imgFromFileNames(cam_idx);
            
            img_path = fullfile("DemoImages",folder_name,imgFromFileName+".bmp");
            if exist(img_path,"file")
                img = imread(img_path);
            else
                disp("Img from file not exist!");
            end
        else
            loop_cam_obg = camera_objects(cam_idx);
            start(loop_cam_obg);
            trigger(loop_cam_obg);
            img = ycbcr2rgb (getsnapshot(loop_cam_obg));
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
        
        if ~isImgFromFile
            stop(loop_cam_obg);
        end

        close(ginput_fig); % close the figure;
    end

    % Save to *.mat file
    save("color_calib.mat","top_ref_array","left_ref_array","right_ref_array","back_ref_array","colors_array");
    
end