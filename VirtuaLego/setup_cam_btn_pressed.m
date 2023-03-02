function [top_cam_idx, left_cam_idx, right_cam_idx, back_cam_idx] = setup_cam_btn_pressed()
    
    % Show subplot of the 4 cameras for setting the top,right,left,back
    % cameras

    global app_state
    app_state = "Setup cameras";
    disp(["App state: ",app_state]);
    
    [top_cam_idx, left_cam_idx, right_cam_idx, back_cam_idx] = setup_cam();

end

function [top_cam_idx, left_cam_idx, right_cam_idx, back_cam_idx] = setup_cam()
    % Get all exist camera
    %delete(imaqfind)
    camlist = webcamlist;
    disp(camlist);
    
    % Remain only the USB camera
    cam_preview = figure;

    amount_of_detected_cameras = length(camlist);
    amount_of_USB_cameras = 0;

    for loop_cam_idx = 1:amount_of_detected_cameras
        if contains(camlist{loop_cam_idx},"FaceTime") == 0 % If not the
        %built in camera
        
            amount_of_USB_cameras = amount_of_USB_cameras+1;
    
            % Show camera with its index in the subplot
            disp("cam id: "+num2str(loop_cam_idx));
            loop_cam = videoinput('winvideo',num2str(loop_cam_idx));
            triggerconfig(loop_cam, 'manual');
            start(loop_cam);
            pause(1);
            loop_img = ycbcr2rgb (getsnapshot(loop_cam));
            subplot(2,2,amount_of_USB_cameras)
            imshow(loop_img);
            title(["Camera index: ",num2str(loop_cam_idx)])
            stop(loop_cam);
            delete(loop_cam);
            pause(1);
        
        end
    end

    top_cam_idx = input("Top camera index? ");
    left_cam_idx = input("Left camera index? ");
    right_cam_idx = input("Right camera index? ");
    back_cam_idx = input("Back camera index? ");

    % save the points in a *.mat file
    save('cam_config.mat','top_cam_idx','left_cam_idx','right_cam_idx',...
    'back_cam_idx');

    close(cam_preview);
end