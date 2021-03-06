/* Copyright 2018 NVIDIA Corporation. All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions
* are met:
*  * Redistributions of source code must retain the above copyright
*    notice, this list of conditions and the following disclaimer.
*  * Redistributions in binary form must reproduce the above copyright
*    notice, this list of conditions and the following disclaimer in the
*    documentation and/or other materials provided with the distribution.
*  * Neither the name of NVIDIA CORPORATION nor the names of its
*    contributors may be used to endorse or promote products derived
*    from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
* PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
* CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
* EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
* PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
* OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
* OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

// # RTC Kernel:
// ** Volume Depth Enhancement **

// # Summary:
// Apply a local front-to-back averaging along a predefined ray segment to darken samples in low
// alpha regions.

// Define the user-defined data structure
struct Depth_enhancement_params
{
  // common lighting params
  int light_mode;     // 0=headlight, 1=orbital
  float angle;        // 0 angle
  float elevation;    // pi/2 angle
  int max_dsteps;     // = 8 [GUI] number of additional samples
  float ash;          // 0.01f adaptive sampling threshold
  float screen_gamma; // 0.9f [GUI] gamma correction parameter

  // shading parameters [GUI / scene]
  float3 spec_color; // make_float3(1.0f) specular color
  float spec_fac;    // 0.2f specular factor (phong)
  float shininess;   // 50.0f shininess parameter (phong)
  float amb_fac;     // 0.4f ambient factor

  float shade_h;   // 0.5f [GUI] min alpha value for shading
  float min_alpha; // 0.001f min alpha for sampling (improves performance)

  float2 dummy;
};

NV_IDX_VOLUME_SAMPLE_PROGRAM_PREFIX
class NV_IDX_volume_sample_program
{
  NV_IDX_VOLUME_SAMPLE_PROGRAM

public:
  const Depth_enhancement_params*
    m_depth_enhancement_params; // define variables to bind user-defined buffer to

public:
  NV_IDX_DEVICE_INLINE_MEMBER
  void init_instance()
  {
    // Bind the contents of the buffer slot 0 to the variable
    m_depth_enhancement_params = NV_IDX_bind_parameter_buffer<Depth_enhancement_params>(0);
  }

  NV_IDX_DEVICE_INLINE_MEMBER
  int execute(const NV_IDX_sample_info_self& sample_info, float4& output_color)
  {
    const NV_IDX_volume& volume = state.self;
    const float3& sample_position = sample_info.sample_position;
    const NV_IDX_colormap& colormap = volume.get_colormap();

    // retrieve parameter buffer contents (fixed values in code definition)
    const float3 wp = sample_info.scene_position;
    const float3 ray_dir = state.m_ray_direction;

    float3 light_dir;
    if (m_depth_enhancement_params->light_mode == 0)
    {
      light_dir = ray_dir;
    }
    else
    {
      const float theta = m_depth_enhancement_params->angle;
      const float phi = m_depth_enhancement_params->elevation;
      light_dir = make_float3(sinf(phi) * cosf(theta), sinf(phi) * sinf(theta), cosf(phi));
    }

    // sample volume
    const float rh = state.m_ray_stepsize_min * 2.0f; // ray sampling difference
    const float3 p0 = sample_position;
    const float3 p1 = sample_position + (ray_dir * rh);

    const float vs_p0 = volume.sample<float>(p0);
    const float vs_p1 = volume.sample<float>(p1);

    const float vs_min = min(vs_p0, vs_p1);
    const float vs_max = max(vs_p0, vs_p1);

    // set adaptive sampling
    int d_steps = m_depth_enhancement_params->max_dsteps;

    if (m_depth_enhancement_params->ash > 0.0f)
    {
      int((vs_max - vs_min) /
        fabsf(m_depth_enhancement_params->ash)); // get number of additional samples
      d_steps = min(d_steps, m_depth_enhancement_params->max_dsteps);
    }

    // compositing front-to-back
    /*const float4&    result;    // C_dst
    const float4&   color;  // C_src
    const float omda = 1.0f - result.w;
    result.x += omda * color.x;
    result.y += omda * color.y;
    result.z += omda * color.z;
    result.w += omda * color.w;*/

    // sample once
    const float4 sample_color = colormap.lookup(vs_p0);
    output_color = make_float4(sample_color.x, sample_color.y, sample_color.z, sample_color.w);

    if (output_color.w < m_depth_enhancement_params->min_alpha)
      return NV_IDX_PROG_DISCARD_SAMPLE;

    if (d_steps > 1)
    {
      // init result color
      float4 result = make_float4(0.0f);

      // iterate steps
      for (int ahc = 0; ahc < d_steps; ahc++)
      {
        // get step size
        const float rt = float(ahc) / float(d_steps);
        const float3 pi = (1.0f - rt) * p0 + rt * p1;
        const float vs_pi = volume.sample<float>(pi);
        const float4 cur_col = colormap.lookup(vs_pi);

        // front-to-back blending
        const float omda = (1.0f - result.w);

        result.x += omda * cur_col.x * cur_col.w;
        result.y += omda * cur_col.y * cur_col.w;
        result.z += omda * cur_col.z * cur_col.w;
        result.w += omda * cur_col.w;
      }

      // assign result color
      output_color = result;
    }
    // local shading
    if (output_color.w > m_depth_enhancement_params->shade_h)
    {
      // get gradient normal
      const float3 vs_grad = volume.get_gradient(sample_position); // compute R3 gradient
      const float3 iso_normal = -normalize(vs_grad);               // get isosurface normal
      // const float vs_grad_mag = length(vs_grad);                            // get gradient
      // magnitude

      // set up lighting parameters
      // const float3 light_dir = normalize(light_pos - wp);
      const float3 view_dir = state.m_ray_direction;

      const float3 diffuse_color = make_float3(output_color);

      const float diff_amnt = fabsf(dot(light_dir, iso_normal)); // two sided shading
      float spec_amnt = 0.0f;

      if (diff_amnt > 0.0f)
      {
        // this is blinn phong
        const float3 H = normalize(light_dir + view_dir);
        const float NH = fabsf(dot(H, iso_normal)); // two sided shading
        spec_amnt = powf(NH, m_depth_enhancement_params->shininess);
      }

      // compute final color (RGB)
      const float3 color_linear =
        diffuse_color * (m_depth_enhancement_params->amb_fac + diff_amnt) +
        m_depth_enhancement_params->spec_color * (spec_amnt * m_depth_enhancement_params->spec_fac);

      // apply gamma correction (assume ambient_color, diffuse_color and spec_color
      // have been linearized, i.e. have no gamma correction in them)
      output_color.x = powf(color_linear.x, float(1.0f / m_depth_enhancement_params->screen_gamma));
      output_color.y = powf(color_linear.y, float(1.0f / m_depth_enhancement_params->screen_gamma));
      output_color.z = powf(color_linear.z, float(1.0f / m_depth_enhancement_params->screen_gamma));

      // apply build in gamma function
      // output_color = gamma_correct(output_color, m_depth_enhancement_params->screen_gamma);

      // clamp result color
      output_color = clamp(output_color, 0.0f, 1.0f);
    }

    return NV_IDX_PROG_OK;
  }
}; // class NV_IDX_volume_sample_program
