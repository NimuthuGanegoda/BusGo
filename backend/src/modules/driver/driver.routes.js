import { Router } from 'express';
import { authenticate } from '../../middleware/auth.middleware.js';
import { validate } from '../../middleware/validate.middleware.js';
import * as controller from './driver.controller.js';
import { z } from 'zod';
import multer from 'multer';

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });
const router = Router();

router.use(authenticate);

router.get('/me',           controller.getProfile);
router.get('/bus',          controller.getMyBus);
router.get('/rating',       controller.getMyRating);
router.get('/trip/current', controller.getCurrentTrip);

router.patch('/location',
  validate(z.object({
    lat:       z.number().min(-90).max(90),
    lng:       z.number().min(-180).max(180),
    heading:   z.number().min(0).max(360).optional(),
    speed_kmh: z.number().min(0).optional(),
  })),
  controller.updateLocation
);

router.patch('/crowd',
  validate(z.object({ crowd_level: z.enum(['low', 'medium', 'high', 'full']) })),
  controller.updateCrowd
);

router.patch('/status',
  validate(z.object({ status: z.enum(['active', 'inactive']) })),
  controller.updateStatus
);

router.post('/upload-license', upload.single('license'), controller.uploadLicense);

export default router;