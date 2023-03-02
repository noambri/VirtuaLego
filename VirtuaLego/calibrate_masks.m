function calibrate_masks()
    % The function calibartes the 4 cameras

    global cam_top cam_left cam_right cam_back cam_demo

    global app_state
    app_state = "Calibrate masks";
    disp(["App state: ",app_state]);

    global isImgFromFile
    imgFromFileNames = ["calib_left","calib_right","calib_back"];
    %imgFromFileNames = ["calib_left","calib_right","calib_back"];

    camera_objects = [cam_left,cam_right,cam_back];
    camera_names = ["cam_left","cam_right","cam_back"];
    %camera_names = ["cam_top"];
    %camera_names = ["cam_left","cam_right","cam_back"];

    img_tforms = load('img_tfrom.mat');

    amount_of_ginput_points = 5;


    for i=1:length(camera_names)
        if ~isImgFromFile
            loop_cam_obg = camera_objects(i);
        end
        loop_cam_name = camera_names(i);
        if ~isImgFromFile
            start(loop_cam_obg);
            trigger(loop_cam_obg);
            cam_img = ycbcr2rgb (getsnapshot(loop_cam_obg));
        else
            img_name = imgFromFileNames(i);
            img_path = fullfile("DemoImages","ImgFromFile",img_name+".bmp");
            if exist(img_path,"file")
                cam_img = imread(img_path);
            else
                disp("Img from file not exist!");
            end
        end

        % Transformation to stright before ginput
        switch loop_cam_name
            case "cam_left"
                stright_cam_img = side_image_geometrical_transformation_for_calib_masks(img_tforms.left_img_tform,cam_img);
            case "cam_right"
                stright_cam_img = side_image_geometrical_transformation_for_calib_masks(img_tforms.right_img_tform,cam_img);
            case "cam_back"
                stright_cam_img = side_image_geometrical_transformation_for_calib_masks(img_tforms.back_img_tform,cam_img);
        end

        ginput_fig = figure;
        
        imshow(stright_cam_img);
        
        switch loop_cam_name
            case "cam_left"
                [cam_left_mask_x, cam_left_mask_y] = ginput(amount_of_ginput_points);
            case "cam_right"
                [cam_right_mask_x, cam_right_mask_y] = ginput(amount_of_ginput_points);
            case "cam_back"
                [cam_back_mask_x, cam_back_mask_y] = ginput(amount_of_ginput_points);
        end

        if ~isImgFromFile
            stop(loop_cam_obg);
        end

        close(ginput_fig);
    end

    % Save all in files
    save("img_sides_masks.mat","cam_left_mask_x","cam_left_mask_y","cam_right_mask_x","cam_right_mask_y","cam_back_mask_x","cam_back_mask_y");

end

function res_img = side_image_geometrical_transformation_for_calib_masks(img_tform,img)

    % Stright the image
    outputView = imref2d(size(img));
    [res_img,~] = imwarp(img,img_tform,'OutputView',outputView); 
end


