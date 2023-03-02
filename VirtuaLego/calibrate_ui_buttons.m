function calibrate_ui_buttons()
    % The function calibartes the 4 cameras

    global cam_top cam_left cam_right cam_back cam_demo

    global app_state
    app_state = "Calibrate cameras";
    disp(["App state: ",app_state]);

    global isImgFromFile

    if isImgFromFile
        img_path = fullfile("DemoImages","ImgFromFile","calib_buttons.bmp");
        if exist(img_path,"file")
            cam_img = imread(img_path);
        else
            disp("Img from file not exist!");
        end
    else
        start(cam_top);
        trigger(cam_top);
        cam_img = ycbcr2rgb (getsnapshot(cam_top));
    end

    amount_of_buttons = 5;
    button_img_tforms = cell(1,5);

    ginput_fig = figure;
    imshow(cam_img);
    
    for btn_idx = 1:amount_of_buttons
        title("mark corners of button no. "+num2str(btn_idx));
        [button_calib_x, button_calib_y] = ginput(4);
        loop_button_tform = generate_button_geometrical_transformation(button_calib_x,button_calib_y);
        button_img_tforms{btn_idx} = loop_button_tform;
    end


    close(ginput_fig);

    if ~isImgFromFile
        stop(cam_top);
    end

    % Same all in files
    save("buttons_tfrom.mat","button_img_tforms");

end

function button_img_tform = generate_button_geometrical_transformation(cam_top_calib_x,cam_top_calib_y)

    global cam_height cam_width
    center_x = cam_width/2;
    center_y = cam_height/2;
    button_size = 40;

    btn_img_input_corners = [cam_top_calib_x(1), cam_top_calib_y(1);...
                             cam_top_calib_x(2), cam_top_calib_y(2);...
                             cam_top_calib_x(3), cam_top_calib_y(3);...
                             cam_top_calib_x(4), cam_top_calib_y(4)];

    % Define the dimension of the top-image after transformation
    btn_img_wanted_corners = [center_x - button_size/2, center_y - button_size/2; ...
                               center_x + button_size/2, center_y - button_size/2; ...
                               center_x + button_size/2, center_y + button_size/2; ...
                               center_x - button_size/2, center_y + button_size/2];


    % Calculating the transformation for strighting the top image
    button_img_tform = estimateGeometricTransform2D(btn_img_input_corners,btn_img_wanted_corners,'projective');
 
end


