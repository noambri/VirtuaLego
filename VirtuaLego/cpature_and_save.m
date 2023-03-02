function cpature_and_save()
    % Capture an image from the camera

    global app_state
    app_state = "Capture and save";
    disp(["App state: ",app_state]);

    global cam_top cam_left cam_right cam_back cam_demo

    global isDemo

    global capture_and_save_img_counter
    global capture_and_save_set_name

    if ~isDemo
        camera_objects = [cam_top,cam_left,cam_right,cam_back];
        camera_names = ["cam_top","cam_left","cam_right","cam_back"];
    else
        camera_objects = [cam_demo];
        camera_names = ["cam_demo"];
    end

    if capture_and_save_set_name == "Empty"
        capture_and_save_set_name = input("Set name?");
    end

    capture_and_save_img_counter = capture_and_save_img_counter+1;
    for i=1:length(camera_objects)
        loop_cam_obg = camera_objects(i);
        loop_cam_name = camera_names(i);
        start(loop_cam_obg);
        trigger(loop_cam_obg);
        img_demo = ycbcr2rgb (getsnapshot(loop_cam_obg));
        %figure;
        %imshow(img_demo);
        new_file_name = loop_cam_name+'_'+num2str(capture_and_save_img_counter)+".bmp";
        new_file_path = fullfile("DemoImages",capture_and_save_set_name,new_file_name);
        imwrite(img_demo,new_file_path);
        disp("Capture and save: "+num2str(capture_and_save_img_counter));
        stop(loop_cam_obg);
    end

end