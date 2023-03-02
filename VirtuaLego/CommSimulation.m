% Simulate the Matlab-Unity connection
clear all
clc

reset_model_txt_descriptor();
while true
    action_type = input("Add = 1, Remove = 2, Button = 3 ? ");

    if action_type == 1 || action_type == 2
        x = input("X = ");
        y = input("Y = ");
        z = input("Z = ");
        w = input("W = ");
        h = input("H = ");
        colors = ["red","yellow","blue","white"];
        color = colors(randi(4));

        if action_type == 1
            action_text = "ADD";
        else
            action_type = "REMOVE";
        end

        new_data = "["+action_text+","+num2str(x)+","+num2str(y)+","+num2str(z)+","+num2str(w)+","+num2str(h)+","+color+"]";
        add_data_to_model_txt_descriptor(new_data);
    else
        btn_idx = input("Button index = ");
        button_action = 3; %input("Action (Press = 1, Release = 2, Both = 3) ? ");
        switch button_action
            case 1
                new_data = "[Button,"+num2str(btn_idx)+",Pressed]";
                add_data_to_model_txt_descriptor(new_data);
            case 2
                new_data = "[Button,"+num2str(btn_idx)+",Release]";
                add_data_to_model_txt_descriptor(new_data);
            case 3
                new_data = "[Button,"+num2str(btn_idx)+",Pressed]";
                add_data_to_model_txt_descriptor(new_data);
                pause(0.25);
                new_data = "[Button,"+num2str(btn_idx)+",Release]";
                add_data_to_model_txt_descriptor(new_data);
        end
    end
end

function add_data_to_model_txt_descriptor(new_data)

    % Read the exist data in the txt file
    fileID = fopen('model_descriptor.txt','r');
    exist_data = fscanf(fileID,'%s');
    fclose(fileID);
    
    % Create the new block
    combined_data = exist_data+"&"+new_data;
    
    % Save the exist data and the new data in the txt file
    fileID=fopen('model_descriptor.txt','w');
    fprintf(fileID,combined_data);
    fclose(fileID);
end

function reset_model_txt_descriptor()
    % Save "[empty_model]" node in the txt file
    fileID=fopen('model_descriptor.txt','w');
    fprintf(fileID,"[empty_model]");
    fclose(fileID);
end