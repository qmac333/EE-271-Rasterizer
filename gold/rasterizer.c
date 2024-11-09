#include "rasterizer.h"
#include <stdlib.h>

#ifdef __cplusplus
#include <vector>
#endif

/* Utility Functions */

/*
 *   Function: min
 *  Function Description: Returns the minimum value of two integers and b.
*/
int min(int a, int b)
{
  // START CODE HERE
  if (a < b)
  {
    return a;
  }
  else
  {
    return b;
  }
  // END CODE HERE
}

/*
 *   Function: max
 *   Function Description: Returns the maximum value of two integers and b.
*/
int max(int a, int b)
{
  // START CODE HERE
  if (a > b)
  {
    return a;
  }
  else
  {
    return b;
  }
  // END CODE HERE
}

/*
/   Function: floor_ss
/   Function Description: Returns a fixed point value rounded down to the subsample grid.
*/
int floor_ss(int val, int r_shift, int ss_w_lg2)
{
  // START CODE HERE
  //r_shift represents the decimal point position
  //ss_w_lg2 represents the number of bits to represent subsample width
  int bits_cut = r_shift - ss_w_lg2;
  int mask = ~((1 << bits_cut)-1);
  return val & mask;
  // return 0;
  // END CODE HERE
}

/*
 *  Function: rastBBox_bbox_fix
 *  Function Description: Determine a bounding box for the triangle.
 *  Note that this is a fixed point function.
*/
BoundingBox get_bounding_box(Triangle triangle, Screen screen, Config config)
{
  BoundingBox bbox;
  // // init bbox to 0
  bbox.lower_left.x = triangle.v[0].x;
  bbox.lower_left.y = triangle.v[0].y;
  bbox.upper_right.x = triangle.v[0].x;
  bbox.upper_right.y = triangle.v[0].y;
  bbox.valid = true;
  // START CODE HERE
  // initialize bounding box to first vertex
  int lowerleft_x = triangle.v[0].x;
  int lowerleft_y = triangle.v[0].y;
  int upperright_x = triangle.v[0].x;
  int upperright_y = triangle.v[0].y;
  // printf("triangle.v[0].x: %d\n", triangle.v[0].x);
  // printf("triangle.v[0].y: %d\n", triangle.v[0].y);
  // printf("triangle.v[1].x: %d\n", triangle.v[1].x);
  // printf("triangle.v[1].y: %d\n", triangle.v[1].y);
  // printf("triangle.v[2].x: %d\n", triangle.v[2].x);
  // printf("triangle.v[2].y: %d\n", triangle.v[2].y);
  // iterate over remaining vertices
  for (int i=0; i<3; i++) {
    lowerleft_x = min(lowerleft_x, triangle.v[i].x);
    lowerleft_y = min(lowerleft_y, triangle.v[i].y);
    upperright_x = max(upperright_x, triangle.v[i].x);
    upperright_y = max(upperright_y, triangle.v[i].y);  }
  // printf("debug1 initial\n");
  // printf("lowerleft_x: %d\n", lowerleft_x);
  // printf("lowerleft_y: %d\n", lowerleft_y);
  // printf("upperright_x: %d\n", upperright_x);
  // printf("upperright_y: %d\n", upperright_y);
  // round down to subsample grid
  bbox.lower_left.x = floor_ss(lowerleft_x, config.r_shift, config.ss_w_lg2);
  bbox.lower_left.y = floor_ss(lowerleft_y, config.r_shift, config.ss_w_lg2);
  bbox.upper_right.x = floor_ss(upperright_x, config.r_shift, config.ss_w_lg2);
  bbox.upper_right.y = floor_ss(upperright_y, config.r_shift, config.ss_w_lg2);
  // printf("debug2 after rounding\n");
  // printf("lowerleft_x: %d\n", bbox.lower_left.x);
  // printf("lowerleft_y: %d\n", bbox.lower_left.y);
  // printf("upperright_x: %d\n", bbox.upper_right.x);
  // printf("upperright_y: %d\n", bbox.upper_right.y);
  // clip to screen
  bbox.upper_right.y = min(screen.height, bbox.upper_right.y);
  bbox.upper_right.x = min(screen.width, bbox.upper_right.x);
  bbox.lower_left.y = max(0, bbox.lower_left.y);
  bbox.lower_left.x = max(0, bbox.lower_left.x);
  // printf("debug3 after clipping\n");
  // printf("screen.width: %d\n", screen.width);
  // printf("screen.height: %d\n", screen.height);
  // printf("lowerleft_x: %d\n", bbox.lower_left.x);
  // printf("lowerleft_y: %d\n", bbox.lower_left.y);
  // printf("upperright_x: %d\n", bbox.upper_right.x);
  // printf("upperright_y: %d\n", bbox.upper_right.y);
  // // check if bbox is valid
  bbox.valid = (bbox.upper_right.x > bbox.lower_left.x) && (bbox.upper_right.y > bbox.lower_left.y);
  // // END CODE HERE
  // printf("debug4\n");
  // printf("valid: %d\n", bbox.valid);
  return bbox;
}

/*
 *  Function: sample_test
 *  Function Description: Checks if sample lies inside triangle
 *
 *
 */
bool sample_test(Triangle triangle, Sample sample)
{
  bool isHit;

  // START CODE HERE
  int x0 = triangle.v[0].x - sample.x;
  int y0 = triangle.v[0].y - sample.y;
  int x1 = triangle.v[1].x - sample.x;
  int y1 = triangle.v[1].y - sample.y;
  int x2 = triangle.v[2].x - sample.x;
  int y2 = triangle.v[2].y - sample.y;

  int cross0 = x0 * y1 - x1 * y0;
  int cross1 = x1 * y2 - x2 * y1;
  int cross2 = x2 * y0 - x0 * y2;

  isHit = (cross0 <= 0 && cross1 <= 0 && cross2 <= 0);
  // END CODE HERE

  return isHit;
}

int rasterize_triangle(Triangle triangle, ZBuff *z, Screen screen, Config config)
{
  int hit_count = 0;

  //Calculate BBox
  BoundingBox bbox = get_bounding_box(triangle, screen, config);

  //Iterate over samples and test if in triangle
  Sample sample;
  for (sample.x = bbox.lower_left.x; sample.x <= bbox.upper_right.x; sample.x += config.ss_i)
  {
    for (sample.y = bbox.lower_left.y; sample.y <= bbox.upper_right.y; sample.y += config.ss_i)
    {

      Sample jitter = jitter_sample(sample, config.ss_w_lg2);
      jitter.x = jitter.x << 2;
      jitter.y = jitter.y << 2;

      Sample jittered_sample;
      jittered_sample.x = sample.x + jitter.x;
      jittered_sample.y = sample.y + jitter.y;

      bool hit = sample_test(triangle, jittered_sample);

      if (hit)
      {
        hit_count++;
        if (z != NULL)
        {
          Sample hit_location;
          hit_location.x = sample.x >> config.r_shift;
          hit_location.y = sample.y >> config.r_shift;

          Sample subsample;
          subsample.x = (sample.x - (hit_location.x << config.r_shift)) / config.ss_i;
          subsample.y = (sample.y - (hit_location.y << config.r_shift)) / config.ss_i;

          Fragment f;
          f.z = triangle.v[0].z;
          f.R = triangle.v[0].R;
          f.G = triangle.v[0].G;
          f.B = triangle.v[0].B;

          process_fragment(z, hit_location, subsample, f);
        }
      }
    }
  }

  return hit_count;
}

void hash_40to8(uchar *arr40, ushort *val, int shift)
{
  uchar arr32[4];
  uchar arr16[2];
  uchar arr8;

  ushort mask = 0x00ff;
  mask = mask >> shift;

  arr32[0] = arr40[0] ^ arr40[1];
  arr32[1] = arr40[1] ^ arr40[2];
  arr32[2] = arr40[2] ^ arr40[3];
  arr32[3] = arr40[3] ^ arr40[4];

  arr16[0] = arr32[0] ^ arr32[2];
  arr16[1] = arr32[1] ^ arr32[3];

  arr8 = arr16[0] ^ arr16[1];

  mask = arr8 & mask;
  val[0] = mask;
}

Sample jitter_sample(const Sample sample, const int ss_w_lg2)
{
  long x = sample.x >> 4;
  long y = sample.y >> 4;
  uchar arr40_1[5];
  uchar arr40_2[5];

  long *arr40_1_ptr = (long *)arr40_1;
  long *arr40_2_ptr = (long *)arr40_2;

  ushort val_x[1];
  ushort val_y[1];

  *arr40_1_ptr = (y << 20) | x;
  *arr40_2_ptr = (x << 20) | y;

  hash_40to8(arr40_1, val_x, ss_w_lg2);
  hash_40to8(arr40_2, val_y, ss_w_lg2);

  Sample jitter;
  jitter.x = val_x[0];
  jitter.y = val_y[0];

  return jitter;
}
