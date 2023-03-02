function calibrate_cameras()
    % The function calibartes the 4 cameras

    global cam_top cam_left cam_right cam_back cam_demo

    global app_state
    app_state = "Calibrate cameras";
    disp(["App state: ",app_state]);

    global isImgFromFile
    imgs_num = input("file index (top_cam_x)? ");
    folder_name = input("folder name?");
    imgFromFileNames = ["cam_top_"+imgs_num,"cam_left_"+imgs_num,"cam_right_"+imgs_num,"cam_back_"+imgs_num];
    %imgFromFileNames = ["calib_left","calib_right","calib_back"];

    camera_objects = [cam_top,cam_left,cam_right,cam_back];
    camera_names = ["cam_top","cam_left","cam_right","cam_back"];

    instructions_img_top = imread(fullfile("DemoImages","ImgFromFile","calib_intructions_top.jpg"));
    instructions_img_side_first = imread(fullfile("DemoImages","ImgFromFile","calib_intructions_side_first.jpg"));
    instructions_img_side_second = imread(fullfile("DemoImages","ImgFromFile","calib_intructions_side_second.jpg"));

    % Load var for un-edited values
    load("img_tfrom.mat","top_img_tform","left_img_tform","right_img_tform","back_img_tform");
    load("img_sides_corners.mat","corns_cam_left_x","corns_cam_left_y","corns_cam_right_x","corns_cam_right_y","corns_cam_back_x","corns_cam_back_y");



    for i=1:length(camera_names)
        if ~isImgFromFile
            loop_cam_obg = camera_objects(i);
        end
        loop_cam_name = camera_names(i);

        to_edit_cam = input("Edit "+loop_cam_name+" camera (1=edit, 0=skip)? ");

        if to_edit_cam == 1

            if ~isImgFromFile
                start(loop_cam_obg);
                trigger(loop_cam_obg);
                cam_img = ycbcr2rgb (getsnapshot(loop_cam_obg));
            else
                img_name = imgFromFileNames(i);
                img_path = fullfile("DemoImages",folder_name,img_name+".bmp");
                if exist(img_path,"file")
                    cam_img = imread(img_path);
                else
                    disp("Img from file not exist!");
                end
            end
    
            ginput_fig = figure;
            subplot(1,2,1);
            imshow(cam_img);
            title(replace(loop_cam_name,'_',' '));
            
    
            if loop_cam_name == "cam_top"
                subplot(1,2,2);
                imshow(instructions_img_top);
                [cam_top_calib_x, cam_top_calib_y] = ginput(4);
                top_img_tform = generate_top_img_geometrical_transformation(cam_top_calib_x,cam_top_calib_y);
            else
                subplot(1,2,2);
                imshow(instructions_img_side_second);
                [cam_side_calib_x, cam_side_calib_y] = ginput(2);
                side_img_tform = generate_side_img_geometrical_transformation(cam_side_calib_x,cam_side_calib_y);
                
                [trans_side_img,~] = imwarp(cam_img,side_img_tform,'OutputView',imref2d(size(cam_img)));
                corners_figure = figure;
    
                subplot(1,2,1);
                imshow(trans_side_img);
    
                subplot(1,2,2);
                imshow(instructions_img_side_first);
                [corns_cam_side_x, corns_cam_side_y] = ginput(8);
                close(corners_figure);
    
                % Save results
                switch loop_cam_name
                    case "cam_left"
                        left_img_tform = side_img_tform;
                        corns_cam_left_x = corns_cam_side_x;
                        corns_cam_left_y = corns_cam_side_y;
                    case "cam_right"
                        right_img_tform = side_img_tform;
                        corns_cam_right_x = corns_cam_side_x;
                        corns_cam_right_y = corns_cam_side_y;
                    case "cam_back"
                        back_img_tform = side_img_tform;
                        corns_cam_back_x = corns_cam_side_x;
                        corns_cam_back_y = corns_cam_side_y;
                end
            end
    
            if ~isImgFromFile
                stop(loop_cam_obg);
            end
    
            close(ginput_fig);
        end
    end

    % Same all in files
    save("img_tfrom.mat","top_img_tform","left_img_tform","right_img_tform","back_img_tform");
    save("img_sides_corners.mat","corns_cam_left_x","corns_cam_left_y","corns_cam_right_x","corns_cam_right_y","corns_cam_back_x","corns_cam_back_y");

end

function top_img_tform = generate_top_img_geometrical_transformation(cam_top_calib_x,cam_top_calib_y)
    global cam_width cam_height
    global top_img_size top_img_grid_resolution


    % ---- Top image transformation ----------------------

    top_img_grid_resolution = top_img_size/24;
    center_x = cam_width/2;
    center_y = cam_height/2;

    top_img_input_corners = [cam_top_calib_x(1), cam_top_calib_y(1);...
                             cam_top_calib_x(2), cam_top_calib_y(2);...
                             cam_top_calib_x(3), cam_top_calib_y(3);...
                             cam_top_calib_x(4), cam_top_calib_y(4)];

    % Define the dimension of the top-image after transformation
    top_img_wanted_corners = [center_x - top_img_size/2, center_y - top_img_size/2; ...
                               center_x + top_img_size/2, center_y - top_img_size/2; ...
                               center_x + top_img_size/2, center_y + top_img_size/2; ...
                               center_x - top_img_size/2, center_y + top_img_size/2];

    

    % Calculating the transformation for strighting the top image
    top_img_tform = estimateGeometricTransform2D(top_img_input_corners,top_img_wanted_corners,'projective');
 
end


function side_img_tform = generate_side_img_geometrical_transformation(cam_side_calib_x,cam_side_calib_y)
    global cam_width cam_height
    global side_img_trapz_row side_img_trapz_width


    % ---- Top image transformation ----------------------

    side_img_input_corners = [cam_side_calib_x(1), cam_side_calib_y(1);...
                             cam_side_calib_x(2), cam_side_calib_y(2)];

    % Define the dimension of the top-image after transformation
    side_img_wanted_corners = [cam_width/2 - side_img_trapz_width/2, side_img_trapz_row; ...
                               cam_width/2 + side_img_trapz_width/2, side_img_trapz_row];


    % Calculating the transformation for strighting the top image
    side_img_tform = estimateGeometricTransform2D(side_img_input_corners,side_img_wanted_corners,'similarity');
 
end

