const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

const std = @import("std");
const engine = @import("../../engine.zig");
const root = @import("root");

var window: ?*c.GLFWwindow = null;

const vertex_shader_text =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\layout (location = 1) in vec2 aTex;
    \\
    \\uniform float scale;
    \\
    \\out vec2 texture_coordinate;
    \\
    \\void main() {
    \\    gl_Position = vec4(
    \\        aPos.x * scale,
    \\        aPos.y * scale * -1.0f, // Flip texture Y axis
    \\        aPos.z * scale,
    \\        1.0f
    \\    );
    \\
    \\    texture_coordinate = aTex;
    \\}
;

const fragment_shader_text =
    \\#version 330 core
    \\
    \\uniform sampler2D tex0;
    \\
    \\in vec2 texture_coordinate;
    \\out vec4 FragColor;
    \\
    \\void main() {
    \\    FragColor = texture(tex0, texture_coordinate);
    \\}
;

const window_width = 640;
const window_height = 480;

pub fn init() void {
    _ = c.glfwSetErrorCallback(&errorCallback);

    if (c.glfwInit() == 0) {
        std.debug.print("glfwInit error!\n", .{});
    }

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    const verticies = [_]c.GLfloat {
//        -1, -1, 0,   1, 1,
//        -1, 1, 0,    1, 0,
//        1, -1, 0,    0, 1,
//        1, 1, 0,     0, 0,
        1, 1, 0,     1, 1,
        1, -1, 0,    1, 0,
        -1, 1, 0,    0, 1,
        -1, -1, 0,   0, 0,
    };

    window = c.glfwCreateWindow(window_width, window_height, "test", null, null);
    if (window == null) {
        std.debug.print("glfwCreateWindow error!\n", .{});
        c.glfwTerminate();
    }

    c.glfwMakeContextCurrent(window);
    _ = c.gladLoadGL();
    c.glfwSwapInterval(1);

    //c.glViewport(0, 0, window_width, window_height);
//        updateViewport();

    const vertex_shader = c.glCreateShader(c.GL_VERTEX_SHADER);
    c.glShaderSource(vertex_shader, 1, &(vertex_shader_text.ptr), null);
    c.glCompileShader(vertex_shader);

    const fragment_shader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(fragment_shader, 1, &(fragment_shader_text.ptr), null);
    c.glCompileShader(fragment_shader);

    const shader_program = ShaderProgram.init();
    defer shader_program.deinit();
    shader_program.attachShader(vertex_shader);
    shader_program.attachShader(fragment_shader);
    shader_program.link();

    c.glDeleteShader(vertex_shader);
    c.glDeleteShader(fragment_shader);

    var vao: [1]c.GLuint = undefined;
    var vbo: [1]c.GLuint = undefined;
    c.glGenVertexArrays(1, &vao);
    c.glGenBuffers(vbo.len, &vbo);
    c.glBindVertexArray(vao[0]);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo[0]);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(verticies)), &verticies, c.GL_STATIC_DRAW);

    //c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(c.GLfloat), null);
    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 5 * @sizeOf(c.GLfloat), null);
    c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, 5 * @sizeOf(c.GLfloat), @ptrFromInt(3 * @sizeOf(c.GLfloat)));
    c.glEnableVertexAttribArray(0);
    c.glEnableVertexAttribArray(1);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    c.glBindVertexArray(0);

    const uniform_id = shader_program.getUniformLocation("scale");
    const texture_uniform_id = shader_program.getUniformLocation("tex0");

    const texture_bytes = [_]u8{
        0xff, 0x00, 0x00, 0, 0x00, 0x00, 0x00, 0, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0, 0x00, 0xff, 0x00, 0, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0, 0x00, 0x00, 0x00, 0, 0x00, 0x00, 0xff,
    };

    var texture: c.GLuint = undefined;
    c.glGenTextures(1, &texture);
    c.glActiveTexture(c.GL_TEXTURE0);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);

//    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, 3, 3, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, &texture_bytes);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, 3, 3, 0, c.GL_RGB, c.GL_UNSIGNED_BYTE, &texture_bytes);
    c.glGenerateMipmap(c.GL_TEXTURE_2D);
    c.glBindTexture(c.GL_TEXTURE_2D, 0);

    c.glUniform1i(texture_uniform_id, 1);

    while (c.glfwWindowShouldClose(window) == 0) {
//        var w: c_int = 0;
  //      var h: c_int = 0;

        updateViewport();

    //    c.glfwGetFramebufferSize(window, &w, &h);
      //  c.glViewport(0, 0, w, h);

        root.update();
        shader_program.use();

        c.glUniform1f(uniform_id, 1);
        c.glBindTexture(c.GL_TEXTURE_2D, texture);

        c.glBindVertexArray(vao[0]);
        c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);


        //std.debug.print("fb: {} {}\n", .{w, h});

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    c.glDeleteVertexArrays(1, &vao);
    c.glDeleteBuffers(1, &vbo);
}

pub fn deinit() void {
    c.glfwDestroyWindow(window);
    c.glfwTerminate();
}

pub fn beginDrawing() void {}
pub fn endDrawing() void {}
pub fn clearBackground(color: engine.Color) void {
    c.glClearColor(
        @as(f32, @floatFromInt(color.r)) / 16,
        @as(f32, @floatFromInt(color.g)) / 16,
        @as(f32, @floatFromInt(color.b)) / 16,
        @as(f32, @floatFromInt(color.a)),
    );
    c.glClear(c.GL_COLOR_BUFFER_BIT);
}

pub fn drawImage(_: engine.ImageNew, _: engine.Coordinate) void {}
pub fn mousePosition() engine.Coordinate {
    return .{ .x = 0, .y = 0 };
}

fn errorCallback(code: c_int, description: [*c]const u8) callconv(.C) void {
    std.debug.print("glfw error: {d} {s}\n", .{ code, description });
}

fn updateViewport() void {
    var w: c_int = 0;
    var h: c_int = 0;

    c.glfwGetFramebufferSize(window, &w, &h);
    c.glViewport(0, 0, w, h);
}

const ShaderProgram = struct {
    id: c.GLuint,

    fn init() ShaderProgram {
        return .{
            .id = c.glCreateProgram(),
        };
    }

    fn deinit(self: ShaderProgram) void {
        c.glDeleteProgram(self.id);
    }

    fn attachShader(self: ShaderProgram, shader_id: c.GLuint) void {
        c.glAttachShader(self.id, shader_id);
    }

    fn use(self: ShaderProgram) void {
        c.glUseProgram(self.id);
    }

    fn link(self: ShaderProgram) void {
        c.glLinkProgram(self.id);
    }

    fn getUniformLocation(self: ShaderProgram, uniform_name: [*:0]const u8) c.GLint {
        return c.glGetUniformLocation(self.id, uniform_name);
    }
};
